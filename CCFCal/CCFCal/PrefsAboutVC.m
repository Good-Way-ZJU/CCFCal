//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "CCFCal.h"
#import "MoTextField.h"
#import "MoVFLHelper.h"

static NSString * const CCFCalGitHubURLString = @"https://github.com/Good-Way-ZJU/CCFCal";

@implementation PrefsAboutVC

- (void)openURLString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openGitHub:(id)sender
{
    #pragma unused(sender)
    [self openURLString:CCFCalGitHubURLString];
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    NSView *v = [NSView new];

    // Convenience function for making labels.
    MoTextField* (^label)(NSString*, BOOL) = ^MoTextField* (NSString *stringValue, BOOL isLink) {
        MoTextField *txt = [MoTextField labelWithString:stringValue];
        if (isLink) {
            txt.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
            txt.linkEnabled = YES;
        }
        [v addSubview:txt];
        return txt;
    };

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSTextField *appName = label(@"CCFCal", NO);
    appName.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];

    NSTextField *version = label([NSString stringWithFormat:@"%@ (%@)", infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]], NO);
    version.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    version.textColor = [NSColor secondaryLabelColor];

    NSTextField *tagline = label(NSLocalizedString(@"A macOS menu bar calendar for tracking the CCF deadlines you subscribe to.", nil), NO);
    tagline.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    tagline.textColor = [NSColor secondaryLabelColor];
    tagline.lineBreakMode = NSLineBreakByWordWrapping;
    tagline.maximumNumberOfLines = 2;

    MoTextField *dataSource = label(NSLocalizedString(@"Data: ccfddl", nil), YES);
    dataSource.urlString = @"https://ccfddl.github.io/";

    MoTextField *upstream = label(NSLocalizedString(@"Based on Itsycal (MIT)", nil), YES);
    upstream.urlString = @"https://github.com/sfsam/Itsycal";

    MoTextField *repository = label(NSLocalizedString(@"GitHub: Good-Way-ZJU/CCFCal", nil), YES);
    repository.urlString = CCFCalGitHubURLString;

    NSButton *starButton = [NSButton buttonWithTitle:NSLocalizedString(@"Star on GitHub", nil) target:self action:@selector(openGitHub:)];
    starButton.bezelStyle = NSBezelStyleRounded;
    starButton.image = [NSImage imageNamed:@"StarButton"];
    starButton.imagePosition = NSImageLeft;
    [v addSubview:starButton];

    NSTextField *features = label(NSLocalizedString(@"Subscribe by CCF rank and field, highlight DDL dates, and show the nearest countdown in the menu bar.", nil), NO);
    features.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    features.textColor = [NSColor secondaryLabelColor];
    features.lineBreakMode = NSLineBreakByWordWrapping;
    features.maximumNumberOfLines = 3;

    NSTextField *copyright1 = label(@"© 2026 CCFCal contributors", NO);
    NSTextField *copyright2 = label(NSLocalizedString(@"Portions © Sanjay Madan / Itsycal, MIT License", nil), NO);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25, @"wide": @360} views:NSDictionaryOfVariableBindings(appName, version, tagline, dataSource, upstream, repository, starButton, features, copyright1, copyright2)];
    [vfl :@"V:|-m-[appName]-10-[tagline]-18-[dataSource]-10-[upstream]-10-[repository]-14-[starButton]-18-[features]-m-[copyright1]-6-[copyright2]-m-|"];
    [vfl :@"H:|-m-[appName]-4-[version]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[tagline(wide)]-(>=m)-|"];
    [vfl :@"H:|-m-[dataSource]-(>=m)-|"];
    [vfl :@"H:|-m-[upstream]-(>=m)-|"];
    [vfl :@"H:|-m-[repository]-(>=m)-|"];
    [vfl :@"H:|-m-[starButton]-(>=m)-|"];
    [vfl :@"H:|-m-[features(wide)]-(>=m)-|"];
    [vfl :@"H:|-m-[copyright1]-(>=m)-|"];
    [vfl :@"H:|-m-[copyright2]-(>=m)-|"];
    
    self.view = v;
}

@end
