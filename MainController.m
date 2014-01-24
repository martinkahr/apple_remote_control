//
//  MainController.m
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006-2014 martinkahr.com. All rights reserved.
//

#import "MainController.h"
#import "AppleRemote.h"
#import "MultiClickRemoteBehavior.h"

@implementation MainController 

- (void) dealloc {
	[_remoteControl autorelease];
	[_remoteBehavior autorelease];
	[super dealloc];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification {
	(void)aNotification;
	NSLog(@"Application will become active - Using remote controls");
	[_remoteControl startListening: self];
}
- (void)applicationWillResignActive:(NSNotification *)aNotification {
	(void)aNotification;
	NSLog(@"Application will resign active - Releasing remote controls");
	[_remoteControl stopListening: self];
}

- (void) awakeFromNib {
	// The MultiClickRemoteBehavior adds extra functionality.
	// It works like a middle man between the delegate and the remote control
	_remoteBehavior = [MultiClickRemoteBehavior new];
	[_remoteBehavior setDelegate: self];
	AppleRemote* newRemoteControl = [[[AppleRemote alloc] initWithDelegate: _remoteBehavior] autorelease];
	
	// set new remote control which will update bindings
	[self setRemoteControl: newRemoteControl];
}

// for bindings access
@synthesize remoteControl = _remoteControl;
@synthesize remoteBehavior = _remoteBehavior;

// delegate method for the MultiClickRemoteBehavior
- (void) remoteButton: (RemoteControlEventIdentifier)buttonIdentifier pressedDown: (BOOL) pressedDown clickCount: (unsigned int)clickCount
{
	NSString* buttonName=nil;
	NSString* pressed=@"";
	
	if (pressedDown) pressed = @"(pressed)"; else pressed = @"(released)";
	
	switch(buttonIdentifier) {
		case kRemoteButtonPlus:
			buttonName = @"Volume up";			
			break;
		case kRemoteButtonMinus:
			buttonName = @"Volume down";
			break;			
		case kRemoteButtonMenu:
			buttonName = @"Menu";
			break;			
		case kRemoteButtonPlay:
			buttonName = @"Play";
			break;			
		case kRemoteButtonRight:	
			buttonName = @"Right";
			break;			
		case kRemoteButtonLeft:
			buttonName = @"Left";
			break;			
		case kRemoteButtonRight_Hold:
			buttonName = @"Right holding";	
			break;	
		case kRemoteButtonLeft_Hold:
			buttonName = @"Left holding";		
			break;			
		case kRemoteButtonPlus_Hold:
			buttonName = @"Volume up holding";	
			break;				
		case kRemoteButtonMinus_Hold:			
			buttonName = @"Volume down holding";	
			break;				
		case kRemoteButtonPlay_Hold:
			buttonName = @"Play (sleep mode)";
			break;			
		case kRemoteButtonMenu_Hold:
			buttonName = @"Menu (long)";
			break;
		case kRemoteControl_Switched:
			buttonName = @"Remote Control Switched";
			break;
		default:
			NSLog(@"Unmapped event for button %d", buttonIdentifier); 
			break;
	}

	NSString* clickCountString = @"";
	if (clickCount > 1) clickCountString = [NSString stringWithFormat: @"%d clicks", clickCount];
	NSString* feedbackString = [NSString stringWithFormat:@"%@ %@ %@", buttonName, pressed, clickCountString];
	[feedbackText setStringValue:feedbackString];
	
	// delegate to view
	[feedbackView remoteButton:buttonIdentifier pressedDown:pressedDown clickCount: clickCount];
	
	// print out events
	NSLog(@"%@", feedbackString);
	if (pressedDown == NO) printf("\n");
	
}

@end
