/*****************************************************************************
 * RemoteControl.h
 * RemoteControlWrapper
 *
 * Created by Martin Kahr on 11.03.06 under a MIT-style license.
 * Copyright (c) 2006-2014 martinkahr.com. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *****************************************************************************/

#import <AppKit/AppKit.h>

// __has_feature is new in the 10.7 SDK, define it here if it's not yet defined.
#ifndef __has_feature
	#define __has_feature(x) 0
#endif

// Create handy #defines that indicate the current memory management model.
#if defined(__OBJC_GC__)
	#define _isMRR 0
	#define _isGC 1
	#define _isARC 0
#elif __has_feature(objc_arc)
	#define _isMRR 0
	#define _isGC 0
	#define _isARC 1
#else
	#define _isMRR 1
	#define _isGC 0
	#define _isARC 0
#endif

// Under GC, CF-type ivars must be explicitly strong;
// but under ARC, doing so is not valid, and will not compile.
#if _isGC
	#define _gcstrong __strong
#else
	#define _gcstrong
#endif

// Under ARC, we sometimes need bridge casts.  Outside ARC they are not needed
// and are not recognized by older compilers.
#if _isARC
	#define _arcbridge __bridge
#else
	#define _arcbridge
#endif

// notification names that are being used to signal that an application wants to
// have access to the remote control device or if the application has finished
// using the remote control device
extern NSString* const REQUEST_FOR_REMOTE_CONTROL_NOTIFCATION;
extern NSString* const FINISHED_USING_REMOTE_CONTROL_NOTIFICATION;

// keys used in user objects for distributed notifications
extern NSString* const kRemoteControlDeviceName;
extern NSString* const kApplicationIdentifier;
extern NSString* const kTargetApplicationIdentifier;

// we have a 6 bit offset to make a hold event out of a normal event
#define EVENT_TO_HOLD_EVENT_OFFSET 6

@class RemoteControl;

typedef enum : int {
	kRemoteButtonInvalid            = -1,
	
	// normal events
	kRemoteButtonPlus				=1<<1,
	kRemoteButtonMinus				=1<<2,
	kRemoteButtonMenu				=1<<3,
	kRemoteButtonPlay				=1<<4,
	kRemoteButtonRight				=1<<5,
	kRemoteButtonLeft				=1<<6,
	
	// hold events
	kRemoteButtonPlus_Hold			=1<<7,
	kRemoteButtonMinus_Hold			=1<<8,
	kRemoteButtonMenu_Hold			=1<<9,
	kRemoteButtonPlay_Hold			=1<<10,
	kRemoteButtonRight_Hold			=1<<11,
	kRemoteButtonLeft_Hold			=1<<12,
	
	// special events (not supported by all devices)
	kRemoteControl_Switched			=1<<13,
} RemoteControlEventIdentifier;

@protocol RemoteControlDelegate <NSObject>

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown remoteControl: (RemoteControl*) remoteControl;

@end

/*
	Base Interface for Remote Control devices
*/
@interface RemoteControl : NSObject {
@private
	id<RemoteControlDelegate> _delegate;
}

// Designated initializer
// returns nil if the remote control device is not available
- (instancetype) initWithDelegate: (id<RemoteControlDelegate>) remoteControlDelegate NS_DESIGNATED_INITIALIZER;

#if _isMRR
@property (readwrite, assign, nonatomic) id<RemoteControlDelegate> delegate;
#else
@property (readwrite, weak, nonatomic) id<RemoteControlDelegate> delegate;
#endif

@property (readwrite, getter=isListeningToRemote, nonatomic) BOOL listeningToRemote;

@property (readwrite, getter=isOpenInExclusiveMode, nonatomic) BOOL openInExclusiveMode;

- (IBAction) startListening: (id) sender;
- (IBAction) stopListening: (id) sender;

// is this remote control sending the given event?
- (BOOL) sendsEventForButtonIdentifier: (RemoteControlEventIdentifier) identifier;

// sending of notifications between applications
+ (void) sendFinishedNotifcationForAppIdentifier: (NSString*) identifier;
+ (void) sendRequestForRemoteControlNotification;

// name of the device
+ (const char*) remoteControlDeviceName;

@end
