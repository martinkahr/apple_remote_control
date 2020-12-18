//
//  RemoteFeedbackView.h
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006-2014 martinkahr.com. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "AppleRemote.h"

NS_ASSUME_NONNULL_BEGIN

@interface RemoteFeedbackView : NSView
{
@private
	NSImage* _remoteImage;
	RemoteControlEventIdentifier _lastButtonIdentifier;
	BOOL _drawn;
}

- (void) remoteButton: (RemoteControlEventIdentifier)buttonIdentifier pressedDown: (BOOL) pressedDown clickCount: (unsigned int)clickCount;

@end

NS_ASSUME_NONNULL_END

