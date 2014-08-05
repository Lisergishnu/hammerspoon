#import "MJExtensionsTabController.h"
#import "MJExtensionManager.h"
#import "MJExtension.h"

#define MJSkipRecommendRestartAlertKey @"MJSkipRecommendRestartAlertKey"

typedef NS_ENUM(NSUInteger, MJCacheItemType) {
    MJCacheItemTypeHeader,
    MJCacheItemTypeNotInstalled,
    MJCacheItemTypeUpToDate,
    MJCacheItemTypeNeedsUpgrade,
    MJCacheItemTypeRemovedRemotely,
};

// oh swift, I do wish you were here already
@interface MJCacheItem : NSObject
@property MJCacheItemType type;
@property MJExtension* ext;
@property NSString* header;
@property BOOL actionize;
@end
@implementation MJCacheItem
+ (MJCacheItem*) header:(NSString*)title {
    MJCacheItem* item = [[MJCacheItem alloc] init];
    item.type = MJCacheItemTypeHeader;
    item.header = title;
    return item;
}
+ (MJCacheItem*) ext:(MJExtension*)ext type:(MJCacheItemType)type {
    MJCacheItem* item = [[MJCacheItem alloc] init];
    item.type = type;
    item.ext = ext;
    return item;
}
@end

@interface MJExtensionsTabController () <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView* extsTable;
@property NSArray* cache;
@property BOOL hasActionsToApply;
@property MJCacheItem* selectedCacheItem;
@end

@implementation MJExtensionsTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"ExtensionsTab"; }
- (NSString*) title   { return @"Extensions"; }
- (NSImage*)  icon    { return [NSImage imageNamed:NSImageNameAdvanced]; }

- (void) awakeFromNib {
    [self rebuildCache];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(extensionsUpdated:)
                                                 name:MJExtensionsUpdatedNotification
                                               object:nil];
}

- (void) rebuildCache {
    NSMutableArray* cache = [NSMutableArray array];
    
    if ([[MJExtensionManager sharedManager].extsNotInstalled count] > 0) {
        [cache addObject: [MJCacheItem header: @"Not Installed"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsNotInstalled)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeNotInstalled]];
    }
    
    if ([[MJExtensionManager sharedManager].extsUpToDate count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - Up to Date"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsUpToDate)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeUpToDate]];
    }
    
    if ([[MJExtensionManager sharedManager].extsNeedingUpgrade count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - Upgrade Available"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsNeedingUpgrade)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeNeedsUpgrade]];
    }
    
    if ([[MJExtensionManager sharedManager].extsRemovedRemotely count] > 0) {
        [cache addObject: [MJCacheItem header: @"Installed - No longer offered publicly!"]];
        for (MJExtension* ext in [MJExtensionManager sharedManager].extsRemovedRemotely)
            [cache addObject: [MJCacheItem ext:ext type:MJCacheItemTypeRemovedRemotely]];
    }
    
    self.hasActionsToApply = NO;
    self.cache = cache;
}

- (void) extensionsUpdated:(NSNotification*)note {
    [self rebuildCache];
    [self.extsTable reloadData];
}

- (MJExtensionManager*) extManager {
    // for use with binding progress animator
    return [MJExtensionManager sharedManager];
}

- (IBAction) updateExtensions:(id)sender {
    [[MJExtensionManager sharedManager] update];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.cache count];
}

- (NSTextField*) headerRow:(NSTableView*)tableView {
    NSTextField *result = [tableView makeViewWithIdentifier:@"header" owner:self];
    if (!result) {
        result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [result setBordered:NO];
        [result setBezelStyle:NSTextFieldRoundedBezel];
        [result setEditable:NO];
        result.identifier = @"header";
    }
    return result;
}

- (NSTextField*) attrRow:(NSTableView*)tableView {
    NSTextField *result = [tableView makeViewWithIdentifier:@"attr" owner:self];
    if (!result) {
        result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [result setDrawsBackground:NO];
        [result setBordered:NO];
        [result setEditable:NO];
        result.identifier = @"attr";
    }
    return result;
}

- (NSButton*) actionRow:(NSTableView*)tableView {
    NSButton* button = [tableView makeViewWithIdentifier:@"useraction" owner:self];
    if (!button) {
        button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 0)];
        [button setButtonType:NSSwitchButton];
        [button setTitle:@""];
        button.identifier = @"useraction";
        button.target = self;
        button.action = @selector(toggleExtAction:);
    }
    return button;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    
    if (item.type == MJCacheItemTypeHeader) {
        NSTextField* header = [self headerRow:tableView];
        header.stringValue = item.header;
        return header;
    }
    else if ([[tableColumn identifier] isEqualToString: @"name"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = [NSString stringWithFormat:@"%@", item.ext.name];
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"version"]) {
        NSTextField* attr = [self attrRow:tableView];
        attr.stringValue = [NSString stringWithFormat:@"%@", item.ext.version];
        return attr;
    }
    else if ([[tableColumn identifier] isEqualToString: @"action"]) {
        NSString* title;
        switch (item.type) {
            case MJCacheItemTypeNeedsUpgrade:    title = @"Upgrade"; break;
            case MJCacheItemTypeNotInstalled:    title = @"Install"; break;
            case MJCacheItemTypeRemovedRemotely: title = @"Uninstall"; break;
            case MJCacheItemTypeUpToDate:        title = @"Uninstall"; break;
            default: break;
        }
        NSButton* action = [self actionRow:tableView];
        action.title = title;
        action.state = item.actionize ? NSOnState : NSOffState;
        return action;
    }
    
    return nil; // unreachable (I hope)
}

- (void) applyChanges {
    NSMutableArray* upgrade = [NSMutableArray array];
    NSMutableArray* install = [NSMutableArray array];
    NSMutableArray* uninstall = [NSMutableArray array];
    
    for (MJCacheItem* item in self.cache) {
        if (!item.actionize)
            continue;
        
        switch (item.type) {
            case MJCacheItemTypeHeader: continue;
            case MJCacheItemTypeNeedsUpgrade:    [upgrade addObject: item.ext]; break;
            case MJCacheItemTypeNotInstalled:    [install addObject: item.ext]; break;
            case MJCacheItemTypeRemovedRemotely: [uninstall addObject: item.ext]; break;
            case MJCacheItemTypeUpToDate:        [uninstall addObject: item.ext]; break;
        }
    }
    
    [[MJExtensionManager sharedManager] upgrade:upgrade
                                        install:install
                                      uninstall:uninstall];
}

- (void) applyChangesAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    BOOL skipNextTime = ([[alert suppressionButton] state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:skipNextTime forKey:MJSkipRecommendRestartAlertKey];
    
    [self applyChanges];
}

- (IBAction) applyActions:(NSButton*)sender {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:MJSkipRecommendRestartAlertKey]) {
        [self applyChanges];
        return;
    }
    
    BOOL recommendRestart = NO;
    for (MJCacheItem* item in self.cache) {
        if (!item.actionize)
            continue;
        
        if (item.type == MJCacheItemTypeRemovedRemotely || item.type == MJCacheItemTypeUpToDate)
            recommendRestart = YES;
    }
    
    if (!recommendRestart) {
        [self applyChanges];
        return;
    }
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle: NSCriticalAlertStyle];
    [alert setMessageText: @"Restart recommended"];
    [alert setInformativeText: @"When you uninstall or upgrade an extension, you may need to restart Mjolnir; otherwise, strange things may happen."];
    [alert setShowsSuppressionButton:YES];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[sender window]
                      modalDelegate:self
                     didEndSelector:@selector(applyChangesAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (IBAction) toggleExtAction:(NSButton*)sender {
    NSInteger row = [self.extsTable rowForView:sender];
    MJCacheItem* item = [self.cache objectAtIndex:row];
    item.actionize = ([sender state] == NSOnState);
    [self recacheHasActionsToApply];
}

- (void) toggleExtViaSpacebar {
    NSInteger row = [self.extsTable selectedRow];
    if (row == -1)
        return;
    
    MJCacheItem* item = [self.cache objectAtIndex:row];
    item.actionize = !item.actionize;
    [self.extsTable reloadData];
    [self.extsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self recacheHasActionsToApply];
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [self.extsTable selectedRow];
    if (row == -1)
        self.selectedCacheItem = nil;
    else
        self.selectedCacheItem = [self.cache objectAtIndex:row];
}

- (void) recacheHasActionsToApply {
    self.hasActionsToApply = [[self.cache filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"actionize == YES"]] count] > 0;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    return item.type != MJCacheItemTypeHeader;
}

- (BOOL) tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    MJCacheItem* item = [self.cache objectAtIndex:row];
    return item.type == MJCacheItemTypeHeader;
}

@end

@interface MJExtensionsTableView : NSTableView
@end

@implementation MJExtensionsTableView

- (void) keyDown:(NSEvent *)theEvent {
    if ([[theEvent characters] isEqualToString: @" "]) {
        MJExtensionsTabController* controller = (id)[self delegate];
        [controller toggleExtViaSpacebar];
    }
    else {
        [super keyDown:theEvent];
    }
}

@end

@interface MJLinkTextField : NSTextField
@end

@implementation MJLinkTextField

- (id) initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [[self cell] setTextColor:[NSColor blueColor]];
    }
    return self;
}

- (void)resetCursorRects {
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}

- (void) mouseDown:(NSEvent *)theEvent {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[self stringValue]]];
}

@end