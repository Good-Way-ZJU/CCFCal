//
//  Created by Sanjay Madan on 12/9/16.
//  Copyright © 2016 Mowglii. All rights reserved.
//

#import <Cocoa/Cocoa.h>

BOOL MOIsLoginItemEnabled(void);
BOOL MOLoginItemRequiresApproval(void);
BOOL MOSetLoginItemEnabled(BOOL enable, NSError **error);
void MOOpenLoginItemsSettings(void);
