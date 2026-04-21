#import "DDLSubscriptionManager.h"

NSNotificationName const DDLSubscriptionsDidChangeNotification = @"DDLSubscriptionsDidChangeNotification";
NSNotificationName const DDLCandidatesDidChangeNotification = @"DDLCandidatesDidChangeNotification";

static NSString * const kDDLSubscribedItemIDs = @"DDLSubscribedItemIDs";
static NSString * const kDDLHighlightColorsByItemID = @"DDLHighlightColorsByItemID";
static NSString * const kDDLPresetColorMigrationKey = @"DDLPresetColorMigrationKey";
static NSString * const kDDLDefaultHighlightColorHex = @"#D62F2B";
static NSString * const kDDLRemoteCandidateFeedURL = @"CCFCalRemoteCandidateFeedURL";
static NSString * const kDDLLastRemoteCandidateRefreshDate = @"DDLLastRemoteCandidateRefreshDate";
static NSTimeInterval const kDDLRemoteCandidateRefreshInterval = 24 * 60 * 60;

static NSString *DDLDefaultColorHexForRank(NSString *rank)
{
    if ([rank isEqualToString:@"B"]) {
        return @"#E0B100";
    }
    if ([rank isEqualToString:@"C"]) {
        return @"#2F6FEB";
    }
    return kDDLDefaultHighlightColorHex;
}

static NSColor *DDLColorFromHexString(NSString *hexString)
{
    NSString *normalized = [[hexString ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([normalized hasPrefix:@"#"]) {
        normalized = [normalized substringFromIndex:1];
    }
    if (normalized.length != 6) {
        normalized = [kDDLDefaultHighlightColorHex substringFromIndex:1];
    }

    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:normalized] scanHexInt:&rgbValue];
    CGFloat red = ((rgbValue >> 16) & 0xFF) / 255.0;
    CGFloat green = ((rgbValue >> 8) & 0xFF) / 255.0;
    CGFloat blue = (rgbValue & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:1.0];
}

@implementation DDLDeadlineEntry
@end

@implementation DDLCandidate
@end

@interface DDLSubscriptionManager ()
@property (nonatomic) NSArray<DDLCandidate *> *candidates;
@property (nonatomic) NSSet<NSString *> *subscribedItemIDs;
@property (nonatomic) NSDictionary<NSString *, NSString *> *highlightColorsByItemID;
@property (nonatomic, copy) NSString *snapshotSource;
@property (nonatomic, copy) NSString *snapshotGeneratedAt;
@end

@implementation DDLSubscriptionManager

- (void)migratePresetColorsIfNeeded
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDDLPresetColorMigrationKey]) {
        return;
    }

    NSMutableDictionary *mutable = [self.highlightColorsByItemID mutableCopy] ?: [NSMutableDictionary new];
    BOOL didChange = NO;
    for (NSString *candidateID in self.subscribedItemIDs) {
        DDLCandidate *candidate = [self candidateForIdentifier:candidateID];
        if (!candidate) continue;
        NSString *stored = mutable[candidateID];
        NSString *recommended = DDLDefaultColorHexForRank(candidate.ccfRank);
        if (stored.length == 0 || ([stored caseInsensitiveCompare:kDDLDefaultHighlightColorHex] == NSOrderedSame && ![candidate.ccfRank isEqualToString:@"A"])) {
            mutable[candidateID] = recommended;
            didChange = YES;
        }
    }
    if (didChange) {
        self.highlightColorsByItemID = [mutable copy];
        [defaults setObject:self.highlightColorsByItemID forKey:kDDLHighlightColorsByItemID];
    }
    [defaults setBool:YES forKey:kDDLPresetColorMigrationKey];
}

- (NSString *)displayStringForTimestamp:(NSString *)timestamp fallback:(NSString *)fallback
{
    if (fallback.length > 0) {
        return fallback;
    }
    if (timestamp.length == 0) {
        return @"";
    }

    NSDateFormatter *parser = [NSDateFormatter new];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssXXXXX";
    NSDate *date = [parser dateFromString:[timestamp stringByReplacingOccurrencesOfString:@"Z" withString:@"+00:00"]];
    if (!date) {
        return @"";
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale currentLocale];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    return [formatter stringFromDate:date];
}

- (NSDate *)dateForTimestamp:(NSString *)timestamp
{
    if (timestamp.length == 0) {
        return nil;
    }
    NSDateFormatter *parser = [NSDateFormatter new];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssXXXXX";
    return [parser dateFromString:[timestamp stringByReplacingOccurrencesOfString:@"Z" withString:@"+00:00"]];
}

+ (instancetype)sharedManager
{
    static DDLSubscriptionManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [DDLSubscriptionManager new];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _candidates = @[];
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kDDLSubscribedItemIDs];
        _subscribedItemIDs = [NSSet setWithArray:saved ?: @[]];
        NSDictionary *savedColors = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDLHighlightColorsByItemID];
        _highlightColorsByItemID = [savedColors isKindOfClass:[NSDictionary class]] ? savedColors : @{};
        _snapshotSource = @"Bundled";
        _snapshotGeneratedAt = @"Unknown";
        [self reloadCandidates];
        [self migratePresetColorsIfNeeded];
    }
    return self;
}

- (void)reloadCandidates
{
    NSURL *url = [self candidateDataURL];
    if (!url) {
        self.candidates = @[];
        return;
    }

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        self.candidates = @[];
        return;
    }

    NSError *error = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || payload == nil) {
        self.candidates = @[];
        return;
    }

    NSArray *items = nil;
    if ([payload isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = payload;
        items = dictionary[@"items"];
        self.snapshotSource = [dictionary[@"source"] isKindOfClass:[NSString class]] ? dictionary[@"source"] : @"ccfddl";
        self.snapshotGeneratedAt = [dictionary[@"generated_at"] isKindOfClass:[NSString class]] ? dictionary[@"generated_at"] : @"Unknown";
    } else if ([payload isKindOfClass:[NSArray class]]) {
        items = payload;
        self.snapshotSource = @"Bundled";
        self.snapshotGeneratedAt = @"Unknown";
    }
    if (![items isKindOfClass:[NSArray class]]) {
        self.candidates = @[];
        return;
    }

    NSMutableArray<DDLCandidate *> *parsed = [NSMutableArray new];
    for (NSDictionary *item in items) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *itemID = item[@"id"];
        NSString *title = item[@"title"];
        NSString *shortName = item[@"short_name"];
        NSString *kind = item[@"kind"];
        NSString *ccfRank = item[@"ccf_rank"];
        NSArray *domains = item[@"domains"];
        NSString *urlString = item[@"url"];
        NSString *nextDeadlineDisplay = item[@"next_deadline_display"];
        NSString *nextDeadlineTimestamp = item[@"next_deadline_timestamp"];
        if (![itemID isKindOfClass:[NSString class]] ||
            ![title isKindOfClass:[NSString class]] ||
            ![shortName isKindOfClass:[NSString class]] ||
            ![kind isKindOfClass:[NSString class]] ||
            ![ccfRank isKindOfClass:[NSString class]] ||
            ![domains isKindOfClass:[NSArray class]] ||
            ![urlString isKindOfClass:[NSString class]]) {
            continue;
        }

        DDLCandidate *candidate = [DDLCandidate new];
        candidate.itemID = itemID;
        candidate.title = title;
        candidate.shortName = shortName;
        candidate.kind = kind;
        candidate.ccfRank = ccfRank;
        candidate.domains = [domains filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject isKindOfClass:[NSString class]];
        }]];
        candidate.url = [NSURL URLWithString:urlString] ?: [NSURL URLWithString:@"https://ccfddl.github.io/"];
        NSString *timestampValue = [nextDeadlineTimestamp isKindOfClass:[NSString class]] ? nextDeadlineTimestamp : @"";
        candidate.nextDeadlineDisplay = [self displayStringForTimestamp:timestampValue fallback:([nextDeadlineDisplay isKindOfClass:[NSString class]] ? nextDeadlineDisplay : @"")];
        candidate.nextDeadlineTimestamp = [nextDeadlineTimestamp isKindOfClass:[NSString class]] ? nextDeadlineTimestamp : @"";
        NSMutableArray<DDLDeadlineEntry *> *deadlines = [NSMutableArray new];
        NSArray *deadlinePayloads = [item[@"deadlines"] isKindOfClass:[NSArray class]] ? item[@"deadlines"] : nil;
        for (NSDictionary *deadlinePayload in deadlinePayloads) {
            if (![deadlinePayload isKindOfClass:[NSDictionary class]]) continue;
            NSString *stage = [deadlinePayload[@"stage"] isKindOfClass:[NSString class]] ? deadlinePayload[@"stage"] : @"Deadline";
            NSString *timestamp = [deadlinePayload[@"timestamp"] isKindOfClass:[NSString class]] ? deadlinePayload[@"timestamp"] : @"";
            if (timestamp.length == 0) continue;
            DDLDeadlineEntry *deadline = [DDLDeadlineEntry new];
            deadline.stage = stage;
            deadline.timestamp = timestamp;
            deadline.displayString = [self displayStringForTimestamp:timestamp fallback:@""];
            [deadlines addObject:deadline];
        }
        if (deadlines.count == 0 && candidate.nextDeadlineTimestamp.length > 0) {
            DDLDeadlineEntry *deadline = [DDLDeadlineEntry new];
            deadline.stage = @"Deadline";
            deadline.timestamp = candidate.nextDeadlineTimestamp;
            deadline.displayString = candidate.nextDeadlineDisplay;
            [deadlines addObject:deadline];
        }
        candidate.deadlines = [deadlines sortedArrayUsingComparator:^NSComparisonResult(DDLDeadlineEntry *left, DDLDeadlineEntry *right) {
            return [left.timestamp compare:right.timestamp];
        }];
        [parsed addObject:candidate];
    }

    self.candidates = [parsed sortedArrayUsingComparator:^NSComparisonResult(DDLCandidate *left, DDLCandidate *right) {
        if (left.nextDeadlineTimestamp.length > 0 && right.nextDeadlineTimestamp.length > 0) {
            NSComparisonResult timestampResult = [left.nextDeadlineTimestamp compare:right.nextDeadlineTimestamp];
            if (timestampResult != NSOrderedSame) {
                return timestampResult;
            }
        } else if (left.nextDeadlineTimestamp.length > 0) {
            return NSOrderedAscending;
        } else if (right.nextDeadlineTimestamp.length > 0) {
            return NSOrderedDescending;
        }
        return [left.shortName compare:right.shortName options:NSCaseInsensitiveSearch];
    }];
}

- (NSURL *)remoteCandidateFeedURL
{
    NSString *urlString = [[NSUserDefaults standardUserDefaults] stringForKey:kDDLRemoteCandidateFeedURL];
    if (urlString.length == 0) {
        id bundledValue = [[NSBundle mainBundle] objectForInfoDictionaryKey:kDDLRemoteCandidateFeedURL];
        if ([bundledValue isKindOfClass:[NSString class]]) {
            urlString = bundledValue;
        }
    }
    urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (urlString.length == 0) {
        return nil;
    }
    return [NSURL URLWithString:urlString];
}

- (NSURL *)candidateOverrideDataURLCreatingDirectory:(BOOL)createDirectory
{
    NSURL *appSupportDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *ccfCalDirectory = [appSupportDirectory URLByAppendingPathComponent:@"CCFCal" isDirectory:YES];
    if (createDirectory && ccfCalDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtURL:ccfCalDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return [ccfCalDirectory URLByAppendingPathComponent:@"DDLCandidates.json"];
}

- (BOOL)candidatePayloadIsValid:(id)payload
{
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id items = payload[@"items"];
    return [items isKindOfClass:[NSArray class]] && [items count] > 0;
}

- (NSError *)remoteCandidateErrorWithDescription:(NSString *)description code:(NSInteger)code
{
    return [NSError errorWithDomain:@"CCFCalRemoteCandidates" code:code userInfo:@{NSLocalizedDescriptionKey: description ?: @"Unable to refresh CCFCal candidate data."}];
}

- (void)refreshRemoteCandidatesIfNeeded
{
    NSDate *lastRefresh = [[NSUserDefaults standardUserDefaults] objectForKey:kDDLLastRemoteCandidateRefreshDate];
    if ([lastRefresh isKindOfClass:[NSDate class]] && [[NSDate date] timeIntervalSinceDate:lastRefresh] < kDDLRemoteCandidateRefreshInterval) {
        return;
    }
    [self refreshRemoteCandidatesWithCompletion:nil];
}

- (void)refreshRemoteCandidatesWithCompletion:(void (^)(BOOL didUpdate, NSError *error))completion
{
    NSURL *feedURL = [self remoteCandidateFeedURL];
    if (!feedURL) {
        if (completion) {
            completion(NO, [self remoteCandidateErrorWithDescription:@"No CCFCal remote candidate feed URL is configured." code:1]);
        }
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:feedURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSError *) = ^(BOOL didUpdate, NSError *finishError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(didUpdate, finishError);
                }
            });
        };

        if (error) {
            finish(NO, error);
            return;
        }
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode < 200 || statusCode >= 300) {
                finish(NO, [self remoteCandidateErrorWithDescription:[NSString stringWithFormat:@"Remote candidate feed returned HTTP %ld.", (long)statusCode] code:2]);
                return;
            }
        }
        if (data.length == 0) {
            finish(NO, [self remoteCandidateErrorWithDescription:@"Remote candidate feed was empty." code:3]);
            return;
        }

        NSError *jsonError = nil;
        id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![self candidatePayloadIsValid:payload]) {
            finish(NO, jsonError ?: [self remoteCandidateErrorWithDescription:@"Remote candidate feed did not match the expected CCFCal JSON shape." code:4]);
            return;
        }

        NSURL *targetURL = [self candidateOverrideDataURLCreatingDirectory:YES];
        NSError *writeError = nil;
        if (![data writeToURL:targetURL options:NSDataWritingAtomic error:&writeError]) {
            finish(NO, writeError);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kDDLLastRemoteCandidateRefreshDate];
            [self reloadCandidates];
            [self migratePresetColorsIfNeeded];
            [[NSNotificationCenter defaultCenter] postNotificationName:DDLCandidatesDidChangeNotification object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:DDLSubscriptionsDidChangeNotification object:self];
            if (completion) {
                completion(YES, nil);
            }
        });
    }];
    [task resume];
}

- (DDLCandidate *)candidateForIdentifier:(NSString *)candidateID
{
    if (candidateID.length == 0) {
        return nil;
    }
    for (DDLCandidate *candidate in self.candidates) {
        if ([candidate.itemID isEqualToString:candidateID]) {
            return candidate;
        }
    }
    return nil;
}

- (NSArray<DDLCandidate *> *)subscribedCandidates
{
    NSMutableArray<DDLCandidate *> *subscribed = [NSMutableArray new];
    for (DDLCandidate *candidate in self.candidates) {
        if ([self.subscribedItemIDs containsObject:candidate.itemID]) {
            [subscribed addObject:candidate];
        }
    }
    return subscribed;
}

- (NSArray<NSDictionary *> *)upcomingSubscribedDeadlinePayloadsWithLimit:(NSUInteger)limit
{
    NSDate *now = [NSDate date];
    NSMutableArray<NSDictionary *> *payloads = [NSMutableArray new];
    for (DDLCandidate *candidate in [self subscribedCandidates]) {
        for (DDLDeadlineEntry *deadline in candidate.deadlines) {
            NSDate *date = [self dateForTimestamp:deadline.timestamp];
            if (!date || [date compare:now] == NSOrderedAscending) {
                continue;
            }
            [payloads addObject:@{
                @"item_id": candidate.itemID ?: @"",
                @"title": candidate.shortName ?: candidate.title ?: @"",
                @"stage": deadline.stage ?: @"Deadline",
                @"timestamp": deadline.timestamp ?: @"",
                @"display": deadline.displayString ?: @"",
                @"ccf_rank": candidate.ccfRank ?: @"",
                @"domains": candidate.domains ?: @[],
                @"kind": candidate.kind ?: @"conference",
                @"url": candidate.url.absoluteString ?: @"",
                @"color_hex": [self highlightColorHexForCandidateID:candidate.itemID] ?: kDDLDefaultHighlightColorHex,
            }];
        }
    }
    [payloads sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"timestamp"] compare:right[@"timestamp"]];
    }];
    if (limit > 0 && payloads.count > limit) {
        return [payloads subarrayWithRange:NSMakeRange(0, limit)];
    }
    return payloads;
}

- (NSURL *)candidateDataURL
{
    NSURL *dynamicURL = [self candidateOverrideDataURLCreatingDirectory:NO];
    if (dynamicURL && [[NSFileManager defaultManager] fileExistsAtPath:dynamicURL.path]) {
        return dynamicURL;
    }
    return [[NSBundle mainBundle] URLForResource:@"DDLCandidates" withExtension:@"json"];
}

- (NSArray<NSString *> *)availableDomains
{
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet new];
    for (DDLCandidate *candidate in self.candidates) {
        for (NSString *domain in candidate.domains) {
            [set addObject:domain];
        }
    }
    return [set.array sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

- (NSArray<DDLCandidate *> *)filteredCandidatesWithSearchText:(NSString *)searchText
                                                selectedRanks:(NSSet<NSString *> *)selectedRanks
                                               selectedDomain:(NSString *)selectedDomain
{
    NSString *normalizedSearch = [[searchText ?: @"" lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *domain = selectedDomain ?: @"";
    BOOL filterByDomain = domain.length > 0 && ![domain isEqualToString:@"All"];

    return [self.candidates filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DDLCandidate *candidate, NSDictionary *bindings) {
        if (selectedRanks.count > 0 && ![selectedRanks containsObject:candidate.ccfRank]) {
            return NO;
        }
        if (filterByDomain && ![candidate.domains containsObject:domain]) {
            return NO;
        }
        if (normalizedSearch.length == 0) {
            return YES;
        }
        NSString *haystack = [[NSString stringWithFormat:@"%@ %@", candidate.title, candidate.shortName] lowercaseString];
        return [haystack containsString:normalizedSearch];
    }]];
}

- (BOOL)isCandidateSubscribed:(DDLCandidate *)candidate
{
    return [self.subscribedItemIDs containsObject:candidate.itemID];
}

- (void)setSubscribed:(BOOL)subscribed forCandidateID:(NSString *)candidateID
{
    NSMutableSet *mutable = [self.subscribedItemIDs mutableCopy];
    if (subscribed) {
        [mutable addObject:candidateID];
    } else {
        [mutable removeObject:candidateID];
    }
    self.subscribedItemIDs = [mutable copy];
    [[NSUserDefaults standardUserDefaults] setObject:self.subscribedItemIDs.allObjects forKey:kDDLSubscribedItemIDs];
    [[NSNotificationCenter defaultCenter] postNotificationName:DDLSubscriptionsDidChangeNotification object:self];
}

- (NSString *)highlightColorHexForCandidateID:(NSString *)candidateID
{
    NSString *stored = self.highlightColorsByItemID[candidateID];
    if (stored.length > 0) {
        return stored;
    }
    DDLCandidate *candidate = [self candidateForIdentifier:candidateID];
    return DDLDefaultColorHexForRank(candidate.ccfRank);
}

- (NSColor *)highlightColorForCandidateID:(NSString *)candidateID
{
    return DDLColorFromHexString([self highlightColorHexForCandidateID:candidateID]);
}

- (void)setHighlightColor:(NSColor *)color forCandidateID:(NSString *)candidateID
{
    if (candidateID.length == 0 || !color) {
        return;
    }
    NSColor *srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!srgb) {
        return;
    }
    CGFloat r, g, b, a;
    [srgb getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02X%02X%02X",
                     (int)round(r * 255.0),
                     (int)round(g * 255.0),
                     (int)round(b * 255.0)];
    NSMutableDictionary *mutable = [self.highlightColorsByItemID mutableCopy] ?: [NSMutableDictionary new];
    mutable[candidateID] = hex;
    self.highlightColorsByItemID = [mutable copy];
    [[NSUserDefaults standardUserDefaults] setObject:self.highlightColorsByItemID forKey:kDDLHighlightColorsByItemID];
}

- (NSString *)metadataValueForKey:(NSString *)key inText:(NSString *)text
{
    if (key.length == 0 || text.length == 0) return @"";
    NSString *prefix = [key stringByAppendingString:@":"];
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if ([line hasPrefix:prefix]) {
            return [line substringFromIndex:prefix.length];
        }
    }
    return @"";
}

- (DDLCandidate *)candidateMatchingEvent:(EKEvent *)event
{
    NSString *itemID = [self itemIDFromText:event.notes];
    if (itemID.length > 0) {
        return [self candidateForIdentifier:itemID];
    }

    NSString *title = event.title ?: @"";
    for (DDLCandidate *candidate in self.candidates) {
        if ([title containsString:candidate.shortName] || [title containsString:candidate.title]) {
            return candidate;
        }
    }
    return nil;
}

- (NSColor *)highlightColorForEvent:(EKEvent *)event
{
    DDLCandidate *candidate = [self candidateMatchingEvent:event];
    if (candidate) {
        return [self highlightColorForCandidateID:candidate.itemID];
    }
    NSString *hex = [self metadataValueForKey:@"color_hex" inText:event.notes ?: @""];
    if (hex.length > 0) {
        return DDLColorFromHexString(hex);
    }
    return DDLColorFromHexString(kDDLDefaultHighlightColorHex);
}

- (BOOL)shouldHighlightEvent:(EKEvent *)event
{
    if (self.subscribedItemIDs.count == 0) return NO;
    NSDate *referenceDate = event.endDate ?: event.startDate;
    if (referenceDate && [referenceDate compare:[NSDate date]] == NSOrderedAscending) {
        return NO;
    }

    NSString *itemID = [self itemIDFromText:event.notes];
    if (itemID.length > 0) {
        return [self.subscribedItemIDs containsObject:itemID];
    }

    NSString *title = event.title ?: @"";
    for (DDLCandidate *candidate in self.candidates) {
        if (![self.subscribedItemIDs containsObject:candidate.itemID]) continue;
        if ([title containsString:candidate.shortName] || [title containsString:candidate.title]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)itemIDFromText:(NSString *)text
{
    if (text.length == 0) return @"";
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if ([line hasPrefix:@"item_id:"]) {
            return [line substringFromIndex:@"item_id:".length];
        }
    }
    return @"";
}

@end
