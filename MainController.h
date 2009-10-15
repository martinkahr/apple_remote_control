//
//  MainController.h
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006 martinkahr.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RemoteControl;
@class MultiClickRemoteBehavior;

@interface MainController : NSObject {
	RemoteControl* remoteControl;
	MultiClickRemoteBehavior* remoteBehavior;
	
	IBOutlet NSView*		feedbackView;
	IBOutlet NSTextField*	feedbackText;
}

- (RemoteControl*) remoteControl;
- (void) setRemoteControl: (RemoteControl*) newControl;


@end
