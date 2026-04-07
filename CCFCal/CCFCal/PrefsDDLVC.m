#import "PrefsDDLVC.h"
#import "DDLSubscriptionManager.h"
#import "MoVFLHelper.h"

static NSString *DDLDisplaySourceLabel(NSString *source)
{
    if (source.length == 0 || [source isEqualToString:@"Bundled"]) {
        return NSLocalizedString(@"Bundled snapshot", @"");
    }
    NSString *normalized = source.lowercaseString;
    if ([normalized containsString:@"ccfddl"] || [normalized containsString:@"ccf4sc"]) {
        return NSLocalizedString(@"Synced from ccfddl", @"");
    }
    return source;
}

static NSString *DDLShortDeadlineDisplay(NSString *fullDisplay)
{
    if (fullDisplay.length < 16) return fullDisplay ?: @"";
    NSDateFormatter *parser = [NSDateFormatter new];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.timeZone = [NSTimeZone localTimeZone];
    parser.dateFormat = @"yyyy-MM-dd HH:mm";
    NSDate *date = [parser dateFromString:fullDisplay];
    if (!date) return fullDisplay;

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale currentLocale];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"MM-dd HH:mm";
    return [formatter stringFromDate:date];
}

static NSString *DDLDomainDisplay(NSArray<NSString *> *domains)
{
    if (domains.count == 0) {
        return @"";
    }
    if (domains.count == 1) {
        return domains.firstObject ?: @"";
    }

    NSUInteger splitIndex = MAX(1, (domains.count + 1) / 2);
    NSArray<NSString *> *firstLineDomains = [domains subarrayWithRange:NSMakeRange(0, splitIndex)];
    NSArray<NSString *> *secondLineDomains = [domains subarrayWithRange:NSMakeRange(splitIndex, domains.count - splitIndex)];
    NSString *firstLine = [firstLineDomains componentsJoinedByString:@" / "];
    NSString *secondLine = [secondLineDomains componentsJoinedByString:@" / "];
    if (secondLine.length == 0) {
        return firstLine;
    }
    return [NSString stringWithFormat:@"%@\n%@", firstLine, secondLine];
}

@interface PrefsDDLVC ()
@end

@implementation PrefsDDLVC
{
    NSButton *_subscribedOnly;
    NSButton *_rankA;
    NSButton *_rankB;
    NSButton *_rankC;
    NSPopUpButton *_domainPopup;
    NSSearchField *_searchField;
    NSTableView *_tableView;
    NSTextField *_summaryLabel;
    NSTextField *_sourceLabel;
    NSTextField *_titleLabel;
    NSTextField *_emptyLabel;
    NSArray<DDLCandidate *> *_filteredCandidates;
    BOOL _didRunInitialAppearanceRefresh;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView
{
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *hero = [NSBox new];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    hero.boxType = NSBoxCustom;
    hero.cornerRadius = 14.0;
    hero.fillColor = [NSColor controlBackgroundColor];
    hero.borderWidth = 0.0;
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:hero];

    _titleLabel = [NSTextField labelWithString:NSLocalizedString(@"Choose the Venues You Want to Track", @"")];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    [hero addSubview:_titleLabel];

    NSTextField *intro = [NSTextField labelWithString:NSLocalizedString(@"Filter venues and subscribe only to the conferences or journals you actually care about.", @"")];
    intro.translatesAutoresizingMaskIntoConstraints = NO;
    intro.lineBreakMode = NSLineBreakByWordWrapping;
    intro.maximumNumberOfLines = 0;
    intro.textColor = [NSColor secondaryLabelColor];
    [hero addSubview:intro];

    _sourceLabel = [NSTextField labelWithString:@""];
    _sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sourceLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightMedium];
    _sourceLabel.textColor = [NSColor secondaryLabelColor];
    [hero addSubview:_sourceLabel];

    NSBox *filtersBox = [NSBox new];
    filtersBox.translatesAutoresizingMaskIntoConstraints = NO;
    filtersBox.boxType = NSBoxCustom;
    filtersBox.cornerRadius = 12.0;
    filtersBox.borderWidth = 1.0;
    filtersBox.borderColor = [NSColor separatorColor];
    filtersBox.fillColor = [NSColor controlBackgroundColor];
    [v addSubview:filtersBox];

    _subscribedOnly = [NSButton checkboxWithTitle:NSLocalizedString(@"Subscribed", @"") target:self action:@selector(filtersChanged:)];
    _subscribedOnly.translatesAutoresizingMaskIntoConstraints = NO;
    [filtersBox addSubview:_subscribedOnly];

    NSTextField *rankLabel = [NSTextField labelWithString:NSLocalizedString(@"CCF Rank", @"")];
    rankLabel.translatesAutoresizingMaskIntoConstraints = NO;
    rankLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [filtersBox addSubview:rankLabel];

    _rankA = [NSButton checkboxWithTitle:@"A" target:self action:@selector(filtersChanged:)];
    _rankB = [NSButton checkboxWithTitle:@"B" target:self action:@selector(filtersChanged:)];
    _rankC = [NSButton checkboxWithTitle:@"C" target:self action:@selector(filtersChanged:)];
    _rankA.translatesAutoresizingMaskIntoConstraints = NO;
    _rankB.translatesAutoresizingMaskIntoConstraints = NO;
    _rankC.translatesAutoresizingMaskIntoConstraints = NO;
    _rankA.state = NSControlStateValueOn;
    _rankB.state = NSControlStateValueOn;
    _rankC.state = NSControlStateValueOn;
    [filtersBox addSubview:_rankA];
    [filtersBox addSubview:_rankB];
    [filtersBox addSubview:_rankC];

    NSTextField *domainLabel = [NSTextField labelWithString:NSLocalizedString(@"Domain:", @"")];
    domainLabel.translatesAutoresizingMaskIntoConstraints = NO;
    domainLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [filtersBox addSubview:domainLabel];

    _domainPopup = [NSPopUpButton new];
    _domainPopup.translatesAutoresizingMaskIntoConstraints = NO;
    [_domainPopup setTarget:self];
    [_domainPopup setAction:@selector(filtersChanged:)];
    [filtersBox addSubview:_domainPopup];

    _searchField = [NSSearchField new];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.delegate = self;
    _searchField.placeholderString = NSLocalizedString(@"Search conference, journal, or acronym", @"");
    [filtersBox addSubview:_searchField];

    _summaryLabel = [NSTextField labelWithString:@""];
    _summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _summaryLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    _summaryLabel.textColor = [NSColor secondaryLabelColor];
    [v addSubview:_summaryLabel];

    _tableView = [NSTableView new];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowSizeStyle = NSTableViewRowSizeStyleLarge;
    _tableView.intercellSpacing = NSMakeSize(0, 2);
    _tableView.usesAlternatingRowBackgroundColors = YES;
    _tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    if (@available(macOS 11.0, *)) {
        _tableView.style = NSTableViewStylePlain;
    }
    NSTableColumn *subscriptionColumn = [[NSTableColumn alloc] initWithIdentifier:@"subscription"];
    subscriptionColumn.title = @"";
    subscriptionColumn.minWidth = 36;
    subscriptionColumn.maxWidth = 36;
    subscriptionColumn.width = 36;
    [_tableView addTableColumn:subscriptionColumn];
    NSTableColumn *candidateColumn = [[NSTableColumn alloc] initWithIdentifier:@"candidate"];
    candidateColumn.title = NSLocalizedString(@"Venue", @"");
    candidateColumn.headerCell.alignment = NSTextAlignmentCenter;
    candidateColumn.minWidth = 132;
    candidateColumn.width = 144;
    [_tableView addTableColumn:candidateColumn];
    NSTableColumn *rankColumn = [[NSTableColumn alloc] initWithIdentifier:@"rank"];
    rankColumn.title = NSLocalizedString(@"Rank", @"");
    rankColumn.headerCell.alignment = NSTextAlignmentCenter;
    rankColumn.minWidth = 70;
    rankColumn.maxWidth = 70;
    rankColumn.width = 70;
    [_tableView addTableColumn:rankColumn];
    NSTableColumn *domainColumn = [[NSTableColumn alloc] initWithIdentifier:@"domain"];
    domainColumn.title = NSLocalizedString(@"Domain", @"");
    domainColumn.headerCell.alignment = NSTextAlignmentCenter;
    domainColumn.minWidth = 126;
    domainColumn.width = 140;
    [_tableView addTableColumn:domainColumn];
    NSTableColumn *deadlineColumn = [[NSTableColumn alloc] initWithIdentifier:@"deadline"];
    deadlineColumn.title = NSLocalizedString(@"Time", @"");
    deadlineColumn.headerCell.alignment = NSTextAlignmentCenter;
    deadlineColumn.minWidth = 180;
    deadlineColumn.maxWidth = 200;
    deadlineColumn.width = 184;
    [_tableView addTableColumn:deadlineColumn];
    [_tableView sizeToFit];

    NSScrollView *scrollView = [NSScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = _tableView;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSNoBorder;
    scrollView.drawsBackground = YES;
    scrollView.backgroundColor = [NSColor controlBackgroundColor];
    
    NSBox *tableBox = [NSBox new];
    tableBox.translatesAutoresizingMaskIntoConstraints = NO;
    tableBox.boxType = NSBoxCustom;
    tableBox.cornerRadius = 12.0;
    tableBox.borderWidth = 1.0;
    tableBox.borderColor = [NSColor separatorColor];
    tableBox.fillColor = [NSColor controlBackgroundColor];
    [v addSubview:tableBox];
    [tableBox addSubview:scrollView];

    _emptyLabel = [NSTextField labelWithString:NSLocalizedString(@"No matching conference or journal. Try broadening the rank or field filters.", @"")];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.alignment = NSTextAlignmentCenter;
    _emptyLabel.textColor = [NSColor secondaryLabelColor];
    _emptyLabel.hidden = YES;
    [v addSubview:_emptyLabel];

    NSDictionary *heroViews = NSDictionaryOfVariableBindings(_titleLabel, intro, _sourceLabel);
    MoVFLHelper *heroVFL = [[MoVFLHelper alloc] initWithSuperview:hero metrics:@{@"m": @18} views:heroViews];
    [heroVFL :@"H:|-m-[_titleLabel]-m-|"];
    [heroVFL :@"H:|-m-[intro]-m-|"];
    [heroVFL :@"H:|-m-[_sourceLabel]-m-|"];
    [heroVFL :@"V:|-m-[_titleLabel]-6-[intro]-10-[_sourceLabel]-m-|"];

    NSDictionary *filterViews = NSDictionaryOfVariableBindings(_subscribedOnly, rankLabel, _rankA, _rankB, _rankC, domainLabel, _domainPopup, _searchField);
    MoVFLHelper *filterVFL = [[MoVFLHelper alloc] initWithSuperview:filtersBox metrics:@{@"m": @14} views:filterViews];
    [filterVFL :@"H:|-m-[_subscribedOnly]-14-[rankLabel]-8-[_rankA]-8-[_rankB]-8-[_rankC]-16-[domainLabel]-[_domainPopup(>=100)]-10-[_searchField(>=80)]-m-|" :NSLayoutFormatAlignAllCenterY];
    [filterVFL :@"V:|-m-[_subscribedOnly]-m-|"];

    NSDictionary *views = NSDictionaryOfVariableBindings(hero, filtersBox, _summaryLabel, tableBox, _emptyLabel);
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:views];
    [vfl :@"H:|-m-[hero]-m-|"];
    [vfl :@"H:|-m-[filtersBox]-m-|"];
    [vfl :@"H:|-m-[_summaryLabel]-m-|"];
    [vfl :@"H:|-m-[tableBox]-m-|"];
    [vfl :@"H:|-40-[_emptyLabel]-40-|"];
    [vfl :@"V:|-m-[hero]-14-[filtersBox]-14-[_summaryLabel]-8-[tableBox(300)]-m-|"];
    [v addConstraint:[NSLayoutConstraint constraintWithItem:_emptyLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tableBox attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [v addConstraint:[NSLayoutConstraint constraintWithItem:_emptyLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tableBox attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    
    NSDictionary *tableViews = NSDictionaryOfVariableBindings(scrollView);
    MoVFLHelper *tableVFL = [[MoVFLHelper alloc] initWithSuperview:tableBox metrics:@{@"m": @0} views:tableViews];
    [tableVFL :@"H:|[scrollView]|"];
    [tableVFL :@"V:|[scrollView]|"];

    self.view = v;
}

- (void)viewDidLayout
{
    [super viewDidLayout];
    if (_tableView.tableColumns.count >= 5) {
        NSTableColumn *candidateColumn = _tableView.tableColumns[1];
        NSTableColumn *domainColumn = _tableView.tableColumns[3];
        NSTableColumn *deadlineColumn = _tableView.tableColumns[4];
        CGFloat totalWidth = NSWidth(_tableView.bounds);
        CGFloat deadlineWidth = 184.0;
        deadlineColumn.width = deadlineWidth;
        CGFloat domainWidth = MIN(MAX(126.0, totalWidth * 0.18), 170.0);
        domainColumn.width = domainWidth;
        CGFloat reservedWidth = 36.0 + 70.0 + domainWidth + deadlineWidth + 12.0;
        candidateColumn.width = MAX(132.0, totalWidth - reservedWidth);
    }
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    DDLSubscriptionManager *manager = [DDLSubscriptionManager sharedManager];
    if (manager.candidates.count == 0) {
        [manager reloadCandidates];
    }
    [self reloadDomainPopup];
    [self applyFilters];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subscriptionsChanged:) name:DDLSubscriptionsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(candidatesChanged:) name:DDLCandidatesDidChangeNotification object:nil];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    if (_didRunInitialAppearanceRefresh) {
        return;
    }
    _didRunInitialAppearanceRefresh = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadDomainPopup];
        [self applyFilters];
        [self.view layoutSubtreeIfNeeded];
        [self->_tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self->_filteredCandidates.count)]];
        [self->_tableView reloadData];
    });
}

- (void)subscriptionsChanged:(NSNotification *)notification
{
    if (_subscribedOnly.state == NSControlStateValueOn) {
        [self applyFilters];
    } else {
        [self updateSummary];
        [_tableView reloadData];
    }
}

- (void)candidatesChanged:(NSNotification *)notification
{
    [self reloadDomainPopup];
    [self applyFilters];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self applyFilters];
}

- (void)filtersChanged:(id)sender
{
    [self applyFilters];
}

- (void)reloadDomainPopup
{
    NSString *previousSelection = _domainPopup.titleOfSelectedItem ?: @"All";
    [_domainPopup removeAllItems];
    [_domainPopup addItemWithTitle:@"All"];
    [_domainPopup addItemsWithTitles:[[DDLSubscriptionManager sharedManager] availableDomains]];
    if ([_domainPopup itemWithTitle:previousSelection]) {
        [_domainPopup selectItemWithTitle:previousSelection];
    }
}

- (NSSet<NSString *> *)selectedRanks
{
    NSMutableSet<NSString *> *ranks = [NSMutableSet new];
    if (_rankA.state == NSControlStateValueOn) [ranks addObject:@"A"];
    if (_rankB.state == NSControlStateValueOn) [ranks addObject:@"B"];
    if (_rankC.state == NSControlStateValueOn) [ranks addObject:@"C"];
    if (ranks.count == 0) {
        [ranks addObjectsFromArray:@[@"A", @"B", @"C"]];
    }
    return ranks;
}

- (void)applyFilters
{
    DDLSubscriptionManager *manager = [DDLSubscriptionManager sharedManager];
    NSArray<DDLCandidate *> *candidates = [manager filteredCandidatesWithSearchText:_searchField.stringValue
                                                                      selectedRanks:[self selectedRanks]
                                                                     selectedDomain:_domainPopup.titleOfSelectedItem];
    if (_subscribedOnly.state == NSControlStateValueOn) {
        NSPredicate *subscribedPredicate = [NSPredicate predicateWithBlock:^BOOL(DDLCandidate *candidate, NSDictionary *bindings) {
            return [manager isCandidateSubscribed:candidate];
        }];
        candidates = [candidates filteredArrayUsingPredicate:subscribedPredicate];
    }
    _filteredCandidates = candidates;
    [self updateSummary];
    [_tableView reloadData];
    _emptyLabel.stringValue = (_subscribedOnly.state == NSControlStateValueOn)
        ? NSLocalizedString(@"No subscribed venues match the current filters.", @"")
        : NSLocalizedString(@"No matching conference or journal. Try broadening the rank or field filters.", @"");
    _emptyLabel.hidden = (_filteredCandidates.count > 0);
}

- (void)updateSummary
{
    NSUInteger subscribedCount = [DDLSubscriptionManager sharedManager].subscribedItemIDs.count;
    DDLSubscriptionManager *manager = [DDLSubscriptionManager sharedManager];
    _summaryLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%lu visible  ·  %lu subscribed", @""), (unsigned long)_filteredCandidates.count, (unsigned long)subscribedCount];
    _sourceLabel.stringValue = [NSString stringWithFormat:@"%@  ·  %@", DDLDisplaySourceLabel(manager.snapshotSource), manager.snapshotGeneratedAt ?: @"Unknown"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _filteredCandidates.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    DDLCandidate *candidate = _filteredCandidates[row];
    if ([tableColumn.identifier isEqualToString:@"subscription"]) {
        NSButton *checkbox = [tableView makeViewWithIdentifier:@"subscription-checkbox" owner:self];
        if (!checkbox) {
            checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(subscriptionToggled:)];
            checkbox.identifier = @"subscription-checkbox";
        }
        checkbox.tag = row;
        checkbox.state = [[DDLSubscriptionManager sharedManager] isCandidateSubscribed:candidate] ? NSControlStateValueOn : NSControlStateValueOff;
        return checkbox;
    }

    if ([tableColumn.identifier isEqualToString:@"deadline"]) {
        NSTableCellView *deadlineCell = [tableView makeViewWithIdentifier:@"deadline-cell" owner:self];
        if (!deadlineCell) {
            deadlineCell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 160, 52)];
            deadlineCell.identifier = @"deadline-cell";

            NSTextField *label = [NSTextField labelWithString:@""];
            label.tag = 2001;
            label.alignment = NSTextAlignmentCenter;
            label.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightBold];
            label.lineBreakMode = NSLineBreakByClipping;
            label.maximumNumberOfLines = 1;
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [deadlineCell addSubview:label];
            [deadlineCell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[label]|" options:0 metrics:nil views:@{@"label": label}]];
            [deadlineCell addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:deadlineCell attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        }
        NSTextField *label = [deadlineCell viewWithTag:2001];
        label.stringValue = candidate.nextDeadlineDisplay.length > 0 ? DDLShortDeadlineDisplay(candidate.nextDeadlineDisplay) : @"--";
        label.toolTip = candidate.nextDeadlineDisplay.length > 0 ? candidate.nextDeadlineDisplay : @"--";
        label.textColor = [[DDLSubscriptionManager sharedManager] isCandidateSubscribed:candidate] ? [NSColor systemRedColor] : [NSColor secondaryLabelColor];
        return deadlineCell;
    }

    if ([tableColumn.identifier isEqualToString:@"rank"]) {
        NSTableCellView *rankCell = [tableView makeViewWithIdentifier:@"rank-cell" owner:self];
        if (!rankCell) {
            rankCell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 70, 52)];
            rankCell.identifier = @"rank-cell";

            NSTextField *label = [NSTextField labelWithString:@""];
            label.tag = 3001;
            label.alignment = NSTextAlignmentCenter;
            label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [rankCell addSubview:label];
            [rankCell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[label]|" options:0 metrics:nil views:@{@"label": label}]];
            [rankCell addConstraint:[NSLayoutConstraint constraintWithItem:label
                                                                  attribute:NSLayoutAttributeCenterY
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:rankCell
                                                                  attribute:NSLayoutAttributeCenterY
                                                                 multiplier:1
                                                                   constant:0]];
        }

        NSTextField *label = [rankCell viewWithTag:3001];
        label.stringValue = [NSString stringWithFormat:@"CCF-%@", candidate.ccfRank];
        if ([candidate.ccfRank isEqualToString:@"A"]) {
            label.textColor = [NSColor systemRedColor];
        } else if ([candidate.ccfRank isEqualToString:@"B"]) {
            label.textColor = [NSColor systemOrangeColor];
        } else {
            label.textColor = [NSColor systemBlueColor];
        }
        return rankCell;
    }

    if ([tableColumn.identifier isEqualToString:@"domain"]) {
        NSTableCellView *domainCell = [tableView makeViewWithIdentifier:@"domain-cell" owner:self];
        if (!domainCell) {
            domainCell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 220, 52)];
            domainCell.identifier = @"domain-cell";

            NSTextField *label = [NSTextField labelWithString:@""];
            label.tag = 4001;
            label.alignment = NSTextAlignmentCenter;
            label.lineBreakMode = NSLineBreakByWordWrapping;
            label.maximumNumberOfLines = 2;
            label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
            label.textColor = [NSColor secondaryLabelColor];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [domainCell addSubview:label];
            [domainCell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[label]-8-|"
                                                                               options:0
                                                                               metrics:nil
                                                                                 views:@{@"label": label}]];
            [domainCell addConstraint:[NSLayoutConstraint constraintWithItem:label
                                                                   attribute:NSLayoutAttributeCenterY
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:domainCell
                                                                   attribute:NSLayoutAttributeCenterY
                                                                  multiplier:1
                                                                    constant:0]];
        }

        NSTextField *label = [domainCell viewWithTag:4001];
        label.stringValue = DDLDomainDisplay(candidate.domains);
        label.toolTip = [candidate.domains componentsJoinedByString:@" / "];
        return domainCell;
    }

    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"candidate-cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 60)];
        cell.identifier = @"candidate-cell";

        NSStackView *stack = [NSStackView new];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.alignment = NSLayoutAttributeCenterX;
        stack.distribution = NSStackViewDistributionFill;
        stack.spacing = 0.0;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:stack];

        NSTextField *title = [NSTextField labelWithString:@""];
        title.tag = 1001;
        title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        title.alignment = NSTextAlignmentCenter;
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        title.maximumNumberOfLines = 2;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:title];

        NSTextField *subtitle = [NSTextField labelWithString:@""];
        subtitle.tag = 1002;
        subtitle.textColor = [NSColor secondaryLabelColor];
        subtitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        subtitle.alignment = NSTextAlignmentCenter;
        subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitle.maximumNumberOfLines = 1;
        subtitle.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:subtitle];

        [cell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-6-[stack]-6-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:@{@"stack": stack}]];
        [cell addConstraint:[NSLayoutConstraint constraintWithItem:stack
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:cell
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1
                                                          constant:0]];
    }

    NSTextField *title = [cell viewWithTag:1001];
    NSTextField *subtitle = [cell viewWithTag:1002];
    title.stringValue = candidate.shortName;
    title.toolTip = candidate.title;
    subtitle.stringValue = [candidate.kind capitalizedString];
    return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 62.0;
}

- (void)subscriptionToggled:(NSButton *)sender
{
    DDLCandidate *candidate = _filteredCandidates[sender.tag];
    [[DDLSubscriptionManager sharedManager] setSubscribed:(sender.state == NSControlStateValueOn) forCandidateID:candidate.itemID];
    if (_subscribedOnly.state == NSControlStateValueOn) {
        [self applyFilters];
    }
}

@end
