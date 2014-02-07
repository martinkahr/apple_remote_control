/*****************************************************************************
 * HIDRemoteControlDevice.h
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
#import <IOKit/hid/IOHIDLib.h>

#import "RemoteControl.h"

// Under GC, CF-type ivars must be explicitly strong;
// but under ARC, doing so is not valid, and will not compile.
#ifdef __OBJC_GC__
	#define _gcstrong __strong
#else
	#define _gcstrong
#endif

/*
	Base class for HID based remote control devices
 */
@interface HIDRemoteControlDevice : RemoteControl {
@private
	IOHIDDeviceInterface** _hidDeviceInterface;
	IOHIDQueueInterface**  _queue;
	_gcstrong CFMutableArrayRef	   _allCookies;
	NSMutableDictionary*   _cookieToButtonMapping;
	
	_gcstrong CFRunLoopSourceRef	   _eventSource;
	
	BOOL _openInExclusiveMode;
	BOOL _processesBacklog;
	
	int _supportedButtonEvents;
}

// When your application needs too much time on the main thread when processing an event other events
// may already be received which are put on a backlog. As soon as your main thread
// has some spare time this backlog is processed and may flood your delegate with calls.
// Backlog processing is turned off by default.
@property (readwrite, nonatomic) BOOL processesBacklog;

// methods that should be overridden by subclasses
- (void) setCookieMappingInDictionary: (NSMutableDictionary*) cookieToButtonMapping;

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown;

+ (const char*) remoteControlDeviceName;

// protected methods
- (void) openRemoteControlDevice;
- (void) closeRemoteControlDevice: (BOOL) shallSendNotifications;

// You must call IOObjectRelease() on the returned value when you are done with it.
+ (io_object_t) findRemoteDevice;

+ (BOOL) isRemoteAvailable;

@end
