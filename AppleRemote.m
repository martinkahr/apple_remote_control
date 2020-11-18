/*****************************************************************************
 * AppleRemote.m
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

#import "AppleRemote.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/IOKitLib.h>

static void IOREInterestCallback(void *			refcon,
								 io_service_t	service,
								 uint32_t		messageType,
								 void *			messageArgument );


@implementation AppleRemote

+ (const char*) remoteControlDeviceName {
	return "AppleIRController";
}

// Designated initializer
- (id) initWithDelegate: (id<RemoteControlDelegate>) inRemoteControlDelegate {
	if ((self = [super initWithDelegate: inRemoteControlDelegate])) {
		// A security update in February of 2007 introduced an odd behavior.
		// Whenever SecureEventInput is activated or deactivated the exclusive access
		// to the apple remote control device is lost. This leads to very strange behavior where
		// a press on the Menu button activates FrontRow while your app still gets the event.
		// A great number of people have complained about this.
		//
		// Finally I found a way to get the state of the SecureEventInput
		// With that information I regain access to the device each time when the SecureEventInput state
		// is changing.
		io_registry_entry_t root = IORegistryGetRootEntry( kIOMasterPortDefault );
		if (root != MACH_PORT_NULL) {
			_notifyPort = IONotificationPortCreate( kIOMasterPortDefault );
			if (_notifyPort) {
				CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(_notifyPort);
				CFRunLoopRef gRunLoop = CFRunLoopGetCurrent();
				CFRunLoopAddSource(gRunLoop, runLoopSource, kCFRunLoopDefaultMode);
				
				io_registry_entry_t entry = IORegistryEntryFromPath( kIOMasterPortDefault, kIOServicePlane ":/");
				if (entry != MACH_PORT_NULL) {
					kern_return_t kr;
					kr = IOServiceAddInterestNotification(_notifyPort,
														  entry,
														  kIOBusyInterest,
														  &IOREInterestCallback,
														  (_arcbridge void *)(self),
														  &_eventSecureInputNotification );
					if (kr != KERN_SUCCESS) {
						NSLog(@"Error when installing EventSecureInput Notification");
						IONotificationPortDestroy(_notifyPort);
						_notifyPort = NULL;
					}
					IOObjectRelease(entry);
				}
			}
			IOObjectRelease(root);
		}
		
		_lastSecureEventInputState = [self retrieveSecureEventInputState];
	}
	return self;
}

#if !_isGC
- (void)dealloc
{
	if (_notifyPort) {
		IONotificationPortDestroy(_notifyPort);
		_notifyPort = NULL;
	}
	
	if (_eventSecureInputNotification) {
		IOObjectRelease (_eventSecureInputNotification);
		_eventSecureInputNotification = MACH_PORT_NULL;
	}
	
#if _isMRR
	[super dealloc];
#endif
}
#endif

#if _isGC
- (void)finalize
{
	if (_notifyPort) {
		IONotificationPortDestroy(_notifyPort);
		_notifyPort = NULL;
	}
	
	if (_eventSecureInputNotification) {
		// Although IOObjectRelease is not documented as thread safe, I was assured at WWDC09 that it is.
		IOObjectRelease (_eventSecureInputNotification);
		_eventSecureInputNotification = MACH_PORT_NULL;
	}
	
	[super finalize];
}
#endif

- (void) setCookieMappingInDictionary: (NSMutableDictionary*) inCookieToButtonMapping	{

	// check if we are using the rb device driver instead of the one from Apple
	io_object_t foundRemoteDevice = [[self class] findRemoteDevice];
	Boolean leopardEmulation = false;
	if (foundRemoteDevice != 0) {
		CFTypeRef leoEmuAttr = IORegistryEntryCreateCFProperty(foundRemoteDevice, CFSTR("RemoteBuddyEmulationV2"), kCFAllocatorDefault, 0);
		if (leoEmuAttr) {
			leopardEmulation = CFEqual(leoEmuAttr, kCFBooleanTrue);
			CFRelease(leoEmuAttr);
		}
		IOObjectRelease(foundRemoteDevice);
	}
	
	if ((floor(NSFoundationVersionNumber) <= 677.00 /*NSFoundationVersionNumber10_5*/) || (leopardEmulation)) {
		// 10.5.x Leopard
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlus]		forKey:@"31_29_28_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMinus]		forKey:@"31_30_28_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMenu]		forKey:@"31_20_19_18_31_20_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay]		forKey:@"31_21_19_18_31_21_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonRight]		forKey:@"31_22_19_18_31_22_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonLeft]		forKey:@"31_23_19_18_31_23_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonRight_Hold]	forKey:@"31_19_18_4_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonLeft_Hold]	forKey:@"31_19_18_3_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMenu_Hold]	forKey:@"31_19_18_31_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay_Hold]	forKey:@"35_31_19_18_35_31_19_18_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteControl_Switched]	forKey:@"19_"];
	} else {
		// 10.6.2 Snow Leopard or later
		// Note: does not work on 10.6.0 and 10.6.1
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlus]		forKey:@"33_31_30_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMinus]		forKey:@"33_32_30_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMenu]		forKey:@"33_22_21_20_2_33_22_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay]		forKey:@"33_23_21_20_2_33_23_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonRight]		forKey:@"33_24_21_20_2_33_24_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonLeft]		forKey:@"33_25_21_20_2_33_25_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonRight_Hold]	forKey:@"33_21_20_14_12_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonLeft_Hold]	forKey:@"33_21_20_13_12_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonMenu_Hold]	forKey:@"33_21_20_2_33_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay_Hold]	forKey:@"37_33_21_20_2_37_33_21_20_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteControl_Switched]	forKey:@"19_"];
		
		// new Aluminum model
		// Mappings changed due to addition of a 7th center button
		// Treat the new center button and play/pause button the same
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay]		forKey:@"33_21_20_8_2_33_21_20_8_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay]		forKey:@"33_21_20_3_2_33_21_20_3_2_"];
		[inCookieToButtonMapping setObject:[NSNumber numberWithInt:kRemoteButtonPlay_Hold]	forKey:@"33_21_20_11_2_33_21_20_11_2_"];
	}

}

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown {
	if (pressedDown == NO && event == kRemoteButtonMenu_Hold) {
		// There is no seperate event for pressed down on menu hold. We are simulating that event here
		[super sendRemoteButtonEvent:event pressedDown:YES];
	}
	
	[super sendRemoteButtonEvent:event pressedDown:pressedDown];
	
	if (pressedDown && (event == kRemoteButtonRight ||
						event == kRemoteButtonLeft ||
						event == kRemoteButtonPlay ||
						event == kRemoteButtonMenu ||
						event == kRemoteButtonPlay_Hold)) {
		// There is no seperate event when the button is being released. We are simulating that event here
		[super sendRemoteButtonEvent:event pressedDown:NO];
	}
}

// overridden to handle a special case with old versions of the rb driver
+ (io_object_t) findRemoteDevice
{
	// Create a CFString version of the remote name.
	const char* remoteControlDeviceName = [self remoteControlDeviceName];
	CFStringRef remoteName = CFStringCreateWithCString(kCFAllocatorDefault, remoteControlDeviceName, kCFStringEncodingUTF8);
	if (!remoteName) {
		return 0;
	}
	
	// Set up a matching dictionary to search the I/O Registry by class
	// name for all HID class devices
	CFMutableDictionaryRef hidMatchDictionary = IOServiceMatching(remoteControlDeviceName);
	
	// Now search I/O Registry for matching devices.
	io_iterator_t hidObjectIterator = 0;
	io_object_t	hidDevice = 0;
	IOReturn ioReturnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, hidMatchDictionary, &hidObjectIterator);
	
	if ((ioReturnValue == kIOReturnSuccess) && (hidObjectIterator != 0)) {
		io_object_t matchingService = 0, foundService = 0;
		BOOL finalMatch = NO;
		
		while ((matchingService = IOIteratorNext(hidObjectIterator))) {
			if (!finalMatch) {
				if (!foundService) {
					if (IOObjectRetain(matchingService) == kIOReturnSuccess) {
						foundService = matchingService;
					}
				}
				
				CFStringRef className = IORegistryEntryCreateCFProperty((io_registry_entry_t)matchingService, CFSTR(kIOClassKey), kCFAllocatorDefault, 0);
				if (className) {
					if (CFStringCompare(className, remoteName, 0) == kCFCompareEqualTo) {
						if (foundService) {
							IOObjectRelease(foundService);
							foundService = 0;
						}
						
						if (IOObjectRetain(matchingService) == kIOReturnSuccess) {
							foundService = matchingService;
							finalMatch = YES;
						}
					}
					
					CFRelease(className);
				}
			}
			
			IOObjectRelease(matchingService);
		}
		
		hidDevice = foundService;
		
		// release the iterator
		IOObjectRelease(hidObjectIterator);
	}
	
	CFRelease(remoteName);
	
	return hidDevice;
}

- (BOOL) retrieveSecureEventInputState {
	BOOL returnValue = NO;
	
	io_registry_entry_t root = IORegistryGetRootEntry( kIOMasterPortDefault );
	if (root != MACH_PORT_NULL) {
		CFArrayRef arrayRef = IORegistryEntrySearchCFProperty(root, kIOServicePlane, CFSTR("IOConsoleUsers"), NULL, kIORegistryIterateRecursively);
		if (arrayRef) {
			CFIndex arrayCount = CFArrayGetCount(arrayRef);
			if (arrayCount > 0) {
				CFStringRef userName = (_arcbridge CFStringRef)NSUserName();
				
				for (CFIndex i=0; i < arrayCount; i++) {
					CFDictionaryRef dict = CFArrayGetValueAtIndex(arrayRef, i);
					CFStringRef sessionUserName = CFDictionaryGetValue(dict, CFSTR("kCGSSessionUserNameKey"));
					if (sessionUserName && CFStringCompare(sessionUserName, userName, 0) == kCFCompareEqualTo) {
						CFTypeRef sessionSecureInputPID = CFDictionaryGetValue(dict, CFSTR("kCGSSessionSecureInputPID"));
						returnValue = (sessionSecureInputPID != NULL);
					}
				}
			}
			CFRelease(arrayRef);
		}
		IOObjectRelease(root);
	}
	return returnValue;
}

- (void) dealWithSecureEventInputChange {
	if ([self isListeningToRemote] == NO || [self isOpenInExclusiveMode] == NO) {
		return;
	}
	
	BOOL newState = [self retrieveSecureEventInputState];
	if (_lastSecureEventInputState == newState) {
		return;
	}
	
	// close and open the device again
	[self closeRemoteControlDevice: NO];
	[self openRemoteControlDevice];
	
	_lastSecureEventInputState = newState;
} 

static void IOREInterestCallback(void *			refcon,
								 io_service_t	service,
								 uint32_t		messageType,
								 void *			messageArgument )
{
	(void)service;
	(void)messageType;
	(void)messageArgument;
	
	// Such a cast is dangerous but should be pretty safe in this case, since when the AppleRemote is deallocated, the callback is cancelled and this function will thereafter not be invoked.
	AppleRemote* remote = (_arcbridge AppleRemote*)refcon;
	
	[remote dealWithSecureEventInputChange];
}

@end
