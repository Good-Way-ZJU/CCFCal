#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const DDLSubscriptionsDidChangeNotification;
extern NSNotificationName const DDLCandidatesDidChangeNotification;

@interface DDLDeadlineEntry : NSObject

@property (nonatomic, copy) NSString *stage;
@property (nonatomic, copy) NSString *timestamp;
@property (nonatomic, copy) NSString *displayString;

@end

@interface DDLCandidate : NSObject

@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *shortName;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, copy) NSString *ccfRank;
@property (nonatomic, copy) NSArray<NSString *> *domains;
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) NSString *nextDeadlineDisplay;
@property (nonatomic, copy) NSString *nextDeadlineTimestamp;
@property (nonatomic, copy) NSArray<DDLDeadlineEntry *> *deadlines;

@end

@interface DDLSubscriptionManager : NSObject

@property (nonatomic, readonly) NSArray<DDLCandidate *> *candidates;
@property (nonatomic, readonly) NSSet<NSString *> *subscribedItemIDs;
@property (nonatomic, readonly) NSString *snapshotSource;
@property (nonatomic, readonly) NSString *snapshotGeneratedAt;

+ (instancetype)sharedManager;

- (void)reloadCandidates;
- (void)refreshRemoteCandidatesIfNeeded;
- (void)refreshRemoteCandidatesWithCompletion:(nullable void (^)(BOOL didUpdate, NSError * _Nullable error))completion;
- (NSArray<NSString *> *)availableDomains;
- (NSArray<DDLCandidate *> *)filteredCandidatesWithSearchText:(NSString *)searchText
                                                selectedRanks:(NSSet<NSString *> *)selectedRanks
                                               selectedDomain:(nullable NSString *)selectedDomain;
- (BOOL)isCandidateSubscribed:(DDLCandidate *)candidate;
- (void)setSubscribed:(BOOL)subscribed forCandidateID:(NSString *)candidateID;
- (NSColor *)highlightColorForCandidateID:(NSString *)candidateID;
- (NSString *)highlightColorHexForCandidateID:(NSString *)candidateID;
- (void)setHighlightColor:(NSColor *)color forCandidateID:(NSString *)candidateID;
- (NSColor *)highlightColorForEvent:(EKEvent *)event;
- (BOOL)shouldHighlightEvent:(EKEvent *)event;
- (nullable DDLCandidate *)candidateForIdentifier:(NSString *)candidateID;
- (NSArray<DDLCandidate *> *)subscribedCandidates;
- (NSArray<NSDictionary *> *)upcomingSubscribedDeadlinePayloadsWithLimit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END
