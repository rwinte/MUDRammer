//
//  SPLFXWorldEditor.m
//  Mudrammer
//
//  Created by Jonathan Hersh on 7/20/14.
//  Copyright (c) 2014 Jonathan Hersh. All rights reserved.
//

#import "SPLFXWorldEditor.h"
#import "SPLTickerForm.h"
#import "SSSoundPickerViewController.h"
#import "JSQSystemSoundPlayer+SSAdditions.h"
#import "SPLAlerts.h"

@interface SPLFXWorldEditor ()

@property (nonatomic, strong) SSMagicManagedObject *record;

@property (nonatomic, strong) World *currentWorld;

@property (nonatomic, strong) UIBarButtonItem *saveButton;

@property (nonatomic, strong) NSManagedObjectContext *editContext;

@end

@implementation SPLFXWorldEditor

+ (instancetype)editorForRecord:(NSManagedObjectID *)recordId
                        inWorld:(NSManagedObjectID *)worldId
                  parentContext:(NSManagedObjectContext *)context {

    SPLFXWorldEditor *editor;

    SSMagicManagedObject *record = [SSMagicManagedObject existingObjectWithId:recordId
                                                                    inContext:context];

    if ([recordId.entity isEqual:[Ticker MR_entityDescription]]) {
        editor = [self formViewControllerWithForm:
                  [SPLTickerForm formForTicker:(Ticker *)record]];

        editor.title = ([record.isHidden boolValue]
                        ? NSLocalizedString(@"NEW_TICKER", nil)
                        : NSLocalizedString(@"EDIT_TICKER", nil));
    }

    editor.record = record;
    editor.editContext = context;
    editor.currentWorld = [World existingObjectWithId:worldId
                                            inContext:context];

    return editor;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [SSThemes configureTable:self.tableView];

    if (![[UIDevice currentDevice] isIPad]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancelEditing:)];
    }

    _saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                target:self
                                                                action:@selector(saveEditing:)];

    self.navigationItem.rightBarButtonItem = self.saveButton;
}

- (CGSize)preferredContentSize {
    // Only calculate size if the view is in the window hierarchy to avoid layout warnings
    if (self.tableView.window) {
        return [self.tableView sizeThatFits:CGSizeMake(320.0f, CGFLOAT_MAX)];
    }
    // Return a reasonable default size when view is not yet in hierarchy
    return CGSizeMake(320.0f, 400.0f);
}

#pragma mark - Actions

- (void)showSoundPicker {
    SSSoundPickerViewController *picker = [SSSoundPickerViewController new];
    picker.selectedFileName = ((SPLTickerForm *)self.formController.form).soundFileName;

    __weak typeof(self) weakSelf = self;
    picker.selectedBlock = ^(NSString *str) {
        __strong typeof(weakSelf) strongSelf = weakSelf; (void)strongSelf;

        SSSound *newSound = [JSQSystemSoundPlayer soundForFileName:str];

        ((SPLTickerForm *)self.formController.form).soundFileName = (newSound
                                                                     ? newSound.fileName
                                                                     : @"None");

        [self.tableView reloadData];
    };

    [self.navigationController pushViewController:picker
                                         animated:YES];
}

- (void) cancelEditing:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) saveEditing:(id)sender {
    [self.tableView endEditing:YES];

    [self bindToObject:self.record];

    if (![self.record canSave]) {
        return;
    }

    self.record.isHidden = @(NO);
    [self.record setValue:self.currentWorld
                   forKey:@"world"];

    [self.record saveObjectWithCompletion:^{
        [self.navigationController popViewControllerAnimated:YES];
    } fail:nil];
}

- (void)deleteCurrentRecord {
    [self.tableView endEditing:YES];

    __weak typeof(self) weakSelf = self;
    NSString *title;

    if( [_record isKindOfClass:[Trigger class]] )
        title = NSLocalizedString(@"DELETE_TRIGGER", nil);
    else if( [_record isKindOfClass:[Alias class]] )
        title = NSLocalizedString(@"DELETE_ALIAS", nil);
    else if( [_record isKindOfClass:[Gag class]] )
        title = NSLocalizedString(@"DELETE_GAG", nil);
    else if ([self.record isKindOfClass:[Ticker class]]) {
        title = NSLocalizedString(@"DELETE_TICKER", nil);
    }

    [SPLAlerts SPLShowActionViewWithTitle:nil
                              cancelTitle:NSLocalizedString(@"CANCEL", @"Cancel")
                              cancelBlock:nil
                         destructiveTitle:title
                         destructiveBlock:^{
                             __strong typeof(weakSelf) strongSelf = weakSelf; (void)strongSelf;
                             [self.record deleteObject];
                             [self.record saveObjectWithCompletion:^{
                                 [self.navigationController popViewControllerAnimated:YES];
                             } fail:nil];
                         }
                            barButtonItem:nil
                               sourceView:self.tableView
                               sourceRect:self.tableView.frame];
}

@end
