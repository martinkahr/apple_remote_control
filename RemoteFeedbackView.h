//
//  RemoteFeedbackView.h
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006-2014 martinkahr.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppleRemote.h"

@interface RemoteFeedbackView : NSView
{
	NSImage* remoteImage;
	RemoteControlEventIdentifier lastButtonIdentifier;
	BOOL drawn;
}

- (void) remoteButton: (RemoteControlEventIdentifier)buttonIdentifier pressedDown: (BOOL) pressedDown clickCount: (unsigned int)clickCount;

@end
