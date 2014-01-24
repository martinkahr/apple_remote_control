//
//  MainController.h
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006-2014 martinkahr.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "MultiClickRemoteBehavior.h"
@class RemoteFeedbackView;

@interface MainController : NSObject <MultiClickRemoteBehaviorDelegate> {
	RemoteControl* remoteControl;
	MultiClickRemoteBehavior* remoteBehavior;
	
	IBOutlet RemoteFeedbackView*		feedbackView;
	IBOutlet NSTextField*	feedbackText;
}

- (RemoteControl*) remoteControl;
- (void) setRemoteControl: (RemoteControl*) newControl;


@end
