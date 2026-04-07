#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const DDLCalendarEventsDidSyncNotification;

extern NSString * const DDLManagedCalendarTitle;
extern NSString * const DDLCountdownSnapshotFileName;
extern NSString * const DDLAppGroupIdentifier;

@interface DDLCalendarSyncManager : NSObject

+ (instancetype)sharedManager;

- (void)syncSubscribedDeadlines;
- (void)syncSubscribedDeadlinesAsync;
- (NSURL *)countdownSnapshotURL;

@end

NS_ASSUME_NONNULL_END
