#import "DDLCalendarSyncManager.h"

#import <AppKit/AppKit.h>
#import <EventKit/EventKit.h>

#import "DDLSubscriptionManager.h"

NSNotificationName const DDLCalendarEventsDidSyncNotification = @"DDLCalendarEventsDidSyncNotification";

NSString * const DDLManagedCalendarTitle = @"DDLCal Subscriptions";
NSString * const DDLCountdownSnapshotFileName = @"DDLCountdownSnapshot.json";

static NSString * const kDDLManagedMarker = @"managed_by:DDLCal";

@interface DDLCalendarSyncManager ()
@property (nonatomic) EKEventStore *store;
@property (nonatomic) dispatch_queue_t syncQueue;
@end

@implementation DDLCalendarSyncManager

+ (instancetype)sharedManager
{
    static DDLCalendarSyncManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [DDLCalendarSyncManager new];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _store = [EKEventStore new];
        _syncQueue = dispatch_queue_create("com.guwei.CCFCal.ddlCalendarSync", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subscriptionStateChanged:) name:DDLSubscriptionsDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subscriptionStateChanged:) name:DDLCandidatesDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)subscriptionStateChanged:(NSNotification *)notification
{
    [self syncSubscribedDeadlinesAsync];
}

- (void)syncSubscribedDeadlinesAsync
{
    dispatch_async(self.syncQueue, ^{
        [self syncSubscribedDeadlines];
    });
}

- (BOOL)calendarAccessGranted
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
    if (@available(macOS 14.0, *)) {
        return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusFullAccess;
    }
#endif
    return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusAuthorized;
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

- (EKSource *)preferredSource
{
    EKCalendar *defaultCalendar = [self.store defaultCalendarForNewEvents];
    if (defaultCalendar.source) {
        return defaultCalendar.source;
    }
    for (EKSource *source in self.store.sources) {
        if (source.sourceType == EKSourceTypeLocal ||
            source.sourceType == EKSourceTypeCalDAV ||
            source.sourceType == EKSourceTypeExchange) {
            return source;
        }
    }
    return self.store.sources.firstObject;
}

- (EKCalendar *)managedCalendarCreatingIfNeeded:(NSError **)error
{
    for (EKCalendar *calendar in [self.store calendarsForEntityType:EKEntityTypeEvent]) {
        if ([calendar.title isEqualToString:DDLManagedCalendarTitle]) {
            return calendar;
        }
    }

    EKSource *source = [self preferredSource];
    if (!source) {
        return nil;
    }

    EKCalendar *calendar = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:self.store];
    calendar.source = source;
    calendar.title = DDLManagedCalendarTitle;
    if (@available(macOS 10.11, *)) {
        calendar.color = [NSColor colorWithRed:0.84 green:0.19 blue:0.17 alpha:1.0];
    }
    if (![self.store saveCalendar:calendar commit:YES error:error]) {
        return nil;
    }
    return calendar;
}

- (NSString *)eventIdentifierForCandidate:(DDLCandidate *)candidate deadline:(DDLDeadlineEntry *)deadline
{
    return [NSString stringWithFormat:@"%@|%@|%@", candidate.itemID ?: @"", deadline.stage ?: @"Deadline", deadline.timestamp ?: @""];
}

- (NSString *)eventTitleForCandidate:(DDLCandidate *)candidate deadline:(DDLDeadlineEntry *)deadline
{
    #pragma unused(deadline)
    return candidate.shortName ?: candidate.title ?: @"Unknown";
}

- (NSString *)eventNotesForCandidate:(DDLCandidate *)candidate deadline:(DDLDeadlineEntry *)deadline
{
    NSString *colorHex = [[DDLSubscriptionManager sharedManager] highlightColorHexForCandidateID:candidate.itemID];
    return [NSString stringWithFormat:@"[DDL]\n%@\nitem_id:%@\nccf_rank:%@\ndomains:%@\nstage:%@\nkind:%@\ncolor_hex:%@\nsource_url:%@",
            kDDLManagedMarker,
            candidate.itemID ?: @"",
            candidate.ccfRank ?: @"",
            [candidate.domains componentsJoinedByString:@","],
            deadline.stage ?: @"Deadline",
            candidate.kind ?: @"conference",
            colorHex ?: @"#D62F2B",
            candidate.url.absoluteString ?: @""];
}

- (NSString *)managedIdentifierFromEvent:(EKEvent *)event
{
    if (event.notes.length == 0 || ![event.notes containsString:kDDLManagedMarker]) {
        return @"";
    }
    NSString *itemID = @"";
    NSString *stage = @"";
    NSArray<NSString *> *lines = [event.notes componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        if ([line hasPrefix:@"item_id:"]) {
            itemID = [line substringFromIndex:@"item_id:".length];
        } else if ([line hasPrefix:@"stage:"]) {
            stage = [line substringFromIndex:@"stage:".length];
        }
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSString *timestamp = [formatter stringFromDate:event.startDate];
    if (itemID.length == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%@|%@|%@", itemID, stage, timestamp];
}

- (NSDictionary<NSString *, NSDictionary *> *)desiredEventPayloads
{
    NSDate *now = [NSDate date];
    NSMutableDictionary<NSString *, NSDictionary *> *payloads = [NSMutableDictionary new];
    for (DDLCandidate *candidate in [[DDLSubscriptionManager sharedManager] subscribedCandidates]) {
        for (DDLDeadlineEntry *deadline in candidate.deadlines) {
            NSDate *date = [self dateForTimestamp:deadline.timestamp];
            if (!date || [date compare:now] == NSOrderedAscending) {
                continue;
            }
            NSString *identifier = [self eventIdentifierForCandidate:candidate deadline:deadline];
            payloads[identifier] = @{
                @"title": [self eventTitleForCandidate:candidate deadline:deadline],
                @"notes": [self eventNotesForCandidate:candidate deadline:deadline],
                @"date": date,
            };
        }
    }
    return payloads;
}

- (NSArray<EKEvent *> *)existingManagedEventsInCalendar:(EKCalendar *)calendar
{
    NSDate *startDate = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitYear value:-1 toDate:[NSDate date] options:0];
    NSDate *endDate = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitYear value:4 toDate:[NSDate date] options:0];
    NSPredicate *predicate = [self.store predicateForEventsWithStartDate:startDate endDate:endDate calendars:@[calendar]];
    NSMutableArray<EKEvent *> *managed = [NSMutableArray new];
    for (EKEvent *event in [self.store eventsMatchingPredicate:predicate]) {
        if ([event.notes containsString:kDDLManagedMarker]) {
            [managed addObject:event];
        }
    }
    return managed;
}

- (NSURL *)countdownSnapshotURL
{
    NSURL *appSupportDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [appSupportDirectory URLByAppendingPathComponent:@"CCFCal" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return [directory URLByAppendingPathComponent:DDLCountdownSnapshotFileName];
}

- (void)writeCountdownSnapshot
{
    NSArray<NSDictionary *> *deadlines = [[DDLSubscriptionManager sharedManager] upcomingSubscribedDeadlinePayloadsWithLimit:8];
    NSDictionary *payload = @{
        @"generated_at": @([[NSDate date] timeIntervalSince1970]),
        @"items": deadlines ?: @[],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToURL:[self countdownSnapshotURL] atomically:YES];
    }
}

- (void)syncSubscribedDeadlines
{
    [self writeCountdownSnapshot];

    if (![self calendarAccessGranted]) {
        return;
    }

    NSError *error = nil;
    EKCalendar *calendar = [self managedCalendarCreatingIfNeeded:&error];
    if (!calendar) {
        return;
    }

    NSDictionary<NSString *, NSDictionary *> *desired = [self desiredEventPayloads];
    NSMutableDictionary<NSString *, EKEvent *> *existingByIdentifier = [NSMutableDictionary new];
    for (EKEvent *event in [self existingManagedEventsInCalendar:calendar]) {
        NSString *identifier = [self managedIdentifierFromEvent:event];
        if (identifier.length > 0) {
            existingByIdentifier[identifier] = event;
        }
    }

    for (NSString *identifier in existingByIdentifier) {
        if (desired[identifier] == nil) {
            [self.store removeEvent:existingByIdentifier[identifier] span:EKSpanThisEvent commit:NO error:nil];
        }
    }

    for (NSString *identifier in desired) {
        NSDictionary *payload = desired[identifier];
        EKEvent *event = existingByIdentifier[identifier] ?: [EKEvent eventWithEventStore:self.store];
        event.calendar = calendar;
        event.title = payload[@"title"];
        event.notes = payload[@"notes"];
        event.startDate = payload[@"date"];
        event.endDate = payload[@"date"];
        event.allDay = NO;
        [self.store saveEvent:event span:EKSpanThisEvent commit:NO error:nil];
    }

    [self.store commit:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DDLCalendarEventsDidSyncNotification object:self];
    });
}

@end
