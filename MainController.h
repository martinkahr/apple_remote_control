//
//  MainController.h
//  RemoteControlWrapper
//
//  Created by Martin Kahr on 16.03.06.
//  Copyright 2006-2014 martinkahr.com. All rights reserved.
//

#import <AppKit/AppKit.h>

#include "MultiClickRemoteBehavior.h"
@class RemoteFeedbackView;

@interface MainController : NSObject <MultiClickRemoteBehaviorDelegate> {
@private
	RemoteControl* _remoteControl;
	MultiClickRemoteBehavior* _remoteBehavior;
	
	IBOutlet RemoteFeedbackView*		feedbackView;
	IBOutlet NSTextField*	feedbackText;
}

@property (readwrite, retain) RemoteControl* remoteControl;

@property (readwrite, retain) MultiClickRemoteBehavior* remoteBehavior;

@end
