//
//  OPCPaletteWindowController.m
//  PaletteCreator
//
//  Created by Olivier Larivain on 1/19/13.
//  Copyright (c) 2013 OpenTable, Inc. All rights reserved.
//

#import <OTFoundation/NSString+Hexa.h>

#import "OTFGlobalConfiguration+PaletteCreator.h"

#import "OPCPaletteWindowController.h"

@interface OPCPaletteWindowController ()
@property (weak) IBOutlet NSTextField *pathField;
@property (weak) IBOutlet NSTextField *paletteNameField;
@property (weak) IBOutlet NSTextField *errorLabel;
@property (weak) IBOutlet NSTextField *successLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *generateButton;

@property (strong) NSOperationQueue *operationQueue;

@property (nonatomic, readwrite, strong) NSURL *plistPath;

@end

@implementation OPCPaletteWindowController

- (void) windowDidLoad {
	[super windowDidLoad];
	
	self.operationQueue = [[NSOperationQueue alloc] init];
	self.operationQueue.maxConcurrentOperationCount = 1;
	
	// set up the opened directory on the open panel
	NSURL *lastPath = [self previousPlistPath];
	self.plistPath = lastPath;
	self.pathField.stringValue = lastPath == nil ? @"" : [lastPath lastPathComponent];
}

- (IBAction)chooseFile:(id)sender {

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseDirectories = NO;
	panel.canChooseFiles = YES;
	panel.resolvesAliases = YES;
	panel.allowsMultipleSelection = NO;

	// set up the opened directory on the open panel
	panel.directoryURL = [self previousPlistDirectory];
	
	[panel beginSheetModalForWindow: self.window completionHandler:^(NSInteger result) {
		[self panel: panel didChooseFile: result];
	}];
}

- (IBAction)generatePalette:(id)sender {
	self.successLabel.stringValue = @"";
	if(self.plistPath == nil) {
		self.errorLabel.stringValue = @"Select a plist containing colors.";
		return;
	}
	
	NSString *paletteName = self.paletteNameField.stringValue;
	if(paletteName.length == 0) {
		self.errorLabel.stringValue = @"Select a palette name.";
		return;
	}
	
	self.errorLabel.stringValue = @"";

	[self.progressIndicator startAnimation: nil];
	self.progressIndicator.hidden = NO;
	self.generateButton.enabled = NO;
	
	OTFVoidBlock block = ^{
		[self generatePaletteWithName: paletteName];
	};
	[self.operationQueue addOperationWithBlock: block];
}

- (void) generatePaletteWithName: (NSString *) name {
	
	// create the color list
	NSColorList *colorList = [NSColorList colorListNamed: name];
	if(colorList != nil) {
		[colorList removeFile];
	}
	
	colorList = [[NSColorList alloc] initWithName: name];
	
	// load the configuration file
	NSString *configurationPath = [self.plistPath path];
	NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile: configurationPath];
	
	// go through all keys and look for colors
	NSColorSpace *colorSpace = [NSColorSpace genericRGBColorSpace];
	NSArray *colors = [configuration objectForKey: @"Colors"];
	for(NSDictionary *color in colors) {
		for(NSString *key in color.allKeys) {
			NSString *value =[color objectForKey: key];
			if (![value isKindOfClass: NSString.class] || ![[value lowercaseString] hasPrefix: @"0x"]) {
				continue;
			}

			NSInteger hex = [value integerFromHexaValue];
			CGFloat red = ((float) ((hex & 0xFF0000) >> 16)) / 255.0f;
			CGFloat green = ((float) ((hex & 0x00FF00) >> 8)) / 255.0f;
			CGFloat blue = ((float) (hex & 0x0000FF)) / 255.0f;
			CGFloat colors[4] = {red, green, blue, 1.0f};
			NSColor *color = [NSColor colorWithColorSpace:colorSpace
											   components: colors
													count: 4];

			NSString *formattedKey = [NSString stringWithFormat:@"%@ (%@)", key, value];
			[colorList setColor: color forKey: formattedKey];
		}
	}
	
	NSString *paletteTargetPath = [NSString stringWithFormat: @"~/%@.clr", name];
	paletteTargetPath = [paletteTargetPath stringByExpandingTildeInPath];
	BOOL saved = [colorList writeToFile: nil];
	if(saved) {
		self.successLabel.stringValue = [NSString stringWithFormat: @"Saved palette %@", name];
	} else {
		self.errorLabel.stringValue = [NSString stringWithFormat: @"Couldn't save palette %@", name];
	}

	
	OTFVoidBlock completion = ^{
		[self.progressIndicator stopAnimation: nil];
		self.progressIndicator.hidden = YES;
		self.generateButton.enabled = YES;
	};
	DispatchMainThread(completion);
	
}

#pragma mark - NSOpenPanel 
- (void) panel: (NSOpenPanel *) panel didChooseFile: (NSInteger) result {
	if(result == NSFileHandlingPanelCancelButton){
		return;
	}
	
	self.plistPath = panel.URL;
	self.pathField.stringValue = [self.plistPath lastPathComponent];
	
	[self persistPlistPath];
}

#pragma mark - previous path persistence and convenience
- (NSURL *) previousPlistPath {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastPathString = [defaults objectForKey: @"lastPlistPath"];
	if(lastPathString == nil) {
		return nil;
	}
	return [NSURL fileURLWithPath: lastPathString];
}

- (void) persistPlistPath {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [self.plistPath path]
				 forKey: @"lastPlistPath"];
	[defaults synchronize];
}

- (NSURL *) previousPlistDirectory {
	NSURL *lastPath = [self previousPlistPath];
	if(lastPath == nil) {
		return [NSURL fileURLWithPath: [@"~/" stringByExpandingTildeInPath]];
	}
	
	return [lastPath URLByDeletingLastPathComponent];
}

@end
