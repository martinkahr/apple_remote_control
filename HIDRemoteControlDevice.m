/*****************************************************************************
 * HIDRemoteControlDevice.m
 * RemoteControlWrapper
 *
 * Created by Martin Kahr on 11.03.06 under a MIT-style license. 
 * Copyright (c) 2006-2016 martinkahr.com. All rights reserved.
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

#import "HIDRemoteControlDevice.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/hid/IOHIDKeys.h>

@interface HIDRemoteControlDevice (PrivateMethods)
- (NSDictionary*) cookieToButtonMapping;
- (IOHIDQueueInterface**) queue;
- (IOHIDDeviceInterface**) hidDeviceInterface;
- (void) handleEventWithCookieString: (NSString*) cookieString sumOfValues: (SInt32) sumOfValues;
- (void) removeNotifcationObserver;
- (void) remoteControlAvailable:(NSNotification *)notification;

@end

@interface HIDRemoteControlDevice (IOKitMethods)
- (IOHIDDeviceInterface**) createInterfaceForDevice: (io_object_t) hidDevice;
- (BOOL) initializeCookies;
- (BOOL) openDevice;
@end

@implementation HIDRemoteControlDevice

// This class acts as an abstract base class - therefore subclasses have to override this method
+ (const char*) remoteControlDeviceName {
	return "";
}

+ (BOOL) isRemoteAvailable {
	io_object_t hidDevice = [self findRemoteDevice];
	if (hidDevice != 0) {
		IOObjectRelease(hidDevice);
		return YES;
	} else {
		return NO;
	}
}

+ (io_object_t) findRemoteDevice {
	CFMutableDictionaryRef hidMatchDictionary = NULL;
	IOReturn ioReturnValue = kIOReturnSuccess;
	io_iterator_t hidObjectIterator = 0;
	io_object_t	hidDevice = 0;
	
	// Set up a matching dictionary to search the I/O Registry by class
	// name for all HID class devices
	hidMatchDictionary = IOServiceMatching([self remoteControlDeviceName]);
	
	// Now search I/O Registry for matching devices.
	ioReturnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, hidMatchDictionary, &hidObjectIterator);
	
	if ((ioReturnValue == kIOReturnSuccess) && (hidObjectIterator != 0)) {
		hidDevice = IOIteratorNext(hidObjectIterator);

		// release the iterator
		IOObjectRelease(hidObjectIterator);
	}
	
	// Returned value must be released by the caller when it is finished
	return hidDevice;
}

// Designated initializer
- (id) initWithDelegate: (id<RemoteControlDelegate>) inRemoteControlDelegate {
	if ([[self class] isRemoteAvailable] == NO) {
#if _isMRR
		[self release];
#endif
		self = nil;
	} else if ( (self = [super initWithDelegate: inRemoteControlDelegate]) ) {
		_openInExclusiveMode = YES;
		_queue = NULL;
		_hidDeviceInterface = NULL;
		_cookieToButtonMapping = [[NSMutableDictionary alloc] init];
		
		[self setCookieMappingInDictionary: _cookieToButtonMapping];

		NSEnumerator* enumerator = [_cookieToButtonMapping objectEnumerator];
		NSNumber* identifier;
		_supportedButtonEvents = 0;
		while( (identifier = [enumerator nextObject]) ) {
			_supportedButtonEvents |= [identifier intValue];
		}
	}
	
	return self;
}

#if !_isGC
- (void) dealloc {
	[self removeNotifcationObserver];
	[self stopListening:self];
#if _isMRR
	[_cookieToButtonMapping release]; _cookieToButtonMapping = nil;
	[super dealloc];
#endif
}
#endif

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown {
	id<RemoteControlDelegate> strongDelegate = [self delegate];
	[strongDelegate sendRemoteButtonEvent: event pressedDown: pressedDown remoteControl:self];
}

- (void) setCookieMappingInDictionary: (NSMutableDictionary*) aCookieToButtonMapping {
	(void)aCookieToButtonMapping;
}
- (int) remoteIdSwitchCookie {
	return 0;
}

- (BOOL) sendsEventForButtonIdentifier: (RemoteControlEventIdentifier) identifier {
	return (_supportedButtonEvents & identifier) == identifier;
}
	
- (BOOL) isListeningToRemote {
	return (_hidDeviceInterface != NULL && _allCookies != NULL && _queue != NULL);
}

- (void) setListeningToRemote: (BOOL) value {
	if (value == NO) {
		[self stopListening:self];
	} else {
		[self startListening:self];
	}
}

@synthesize openInExclusiveMode = _openInExclusiveMode;

@synthesize processesBacklog = _processesBacklog;

- (void) openRemoteControlDevice {
	io_object_t hidDevice = [[self class] findRemoteDevice];
	if (hidDevice == 0) {
		return;
	}
	
	if ([self createInterfaceForDevice:hidDevice] == NULL) {
		goto error;
	}
	
	if ([self initializeCookies]==NO) {
		goto error;
	}
	
	if ([self openDevice]==NO) {
		goto error;
	}
	goto cleanup;
	
error:
	[self stopListening:self];
	
cleanup:	
	IOObjectRelease(hidDevice);	
}

- (void) closeRemoteControlDevice: (BOOL) shallSendNotifications {
	BOOL sendNotification = NO;
	
	if (_eventSource != NULL) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _eventSource, kCFRunLoopDefaultMode);
		CFRelease(_eventSource);
		_eventSource = NULL;
	}
	if (_queue != NULL) {
		(*_queue)->stop(_queue);
		
		//dispose of queue
		(*_queue)->dispose(_queue);
		
		//release the queue we allocated
		(*_queue)->Release(_queue);
		
		_queue = NULL;
		
		sendNotification = YES;
	}
	
	if (_allCookies != NULL) {
		CFRelease(_allCookies);
		_allCookies = NULL;
	}
	
	if (_hidDeviceInterface != NULL) {
		//close the device
		(*_hidDeviceInterface)->close(_hidDeviceInterface);
		
		//release the interface	
		(*_hidDeviceInterface)->Release(_hidDeviceInterface);
		
		_hidDeviceInterface = NULL;
	}
	
	if (shallSendNotifications && [self isOpenInExclusiveMode] && sendNotification) {
		[[self class] sendFinishedNotifcationForAppIdentifier: nil];
	}
}

- (IBAction) startListening: (id) sender {
	(void)sender;
	
	if ([self isListeningToRemote]) {
		return;
	}
	
	[self willChangeValueForKey:@"listeningToRemote"];

	[self openRemoteControlDevice];
	
	[self didChangeValueForKey:@"listeningToRemote"];
}

- (IBAction) stopListening: (id) sender {
	(void)sender;

	if ([self isListeningToRemote]==NO) {
		return;
	}
	
	[self willChangeValueForKey:@"listeningToRemote"];
	
	[self closeRemoteControlDevice: YES];
	
	[self didChangeValueForKey:@"listeningToRemote"];
}

@end

@implementation HIDRemoteControlDevice (PrivateMethods)

- (IOHIDQueueInterface**) queue {
	return _queue;
}

- (IOHIDDeviceInterface**) hidDeviceInterface {
	return _hidDeviceInterface;
}


- (NSDictionary*) cookieToButtonMapping {
	return _cookieToButtonMapping;
}

- (NSString*) validCookieSubstring: (NSString*) cookieString {
	if ([cookieString length] == 0) {
		return nil;
	}
	NSEnumerator* keyEnum = [[self cookieToButtonMapping] keyEnumerator];
	NSString* key;
	
	// find the best match
	while( (key = [keyEnum nextObject]) ) {
		NSRange range = [cookieString rangeOfString:key];
		if (range.location == 0) {
			return key;
		}
	}
	return nil;
}

- (void) handleEventWithCookieString: (NSString*) cookieString sumOfValues: (SInt32) sumOfValues {
	/*
	if (previousRemainingCookieString) {
		cookieString = [previousRemainingCookieString stringByAppendingString: cookieString];
		NSLog(@"New cookie string is %@", cookieString);
		[previousRemainingCookieString release], previousRemainingCookieString=nil;
	}*/
	if ([cookieString length] == 0) {
		return;
	}
	
	NSNumber* buttonId = [[self cookieToButtonMapping] objectForKey: cookieString];
	if (buttonId != nil) {
		RemoteControlEventIdentifier remoteControlEvent = (RemoteControlEventIdentifier)[buttonId intValue];
		[self sendRemoteButtonEvent: remoteControlEvent pressedDown: (sumOfValues>0)];
	} else {
		// let's see if this is the first event after a restart of the OS.
		// In this case the event has a prefix that we can ignore and we just get the down event but no up event
		NSEnumerator* keyEnum = [[self cookieToButtonMapping] keyEnumerator];
		NSString* key;
		while( (key = [keyEnum nextObject]) ) {
			NSRange range = [cookieString rangeOfString:key];
			if (range.location != NSNotFound && range.location > 0) {
				buttonId = [[self cookieToButtonMapping] objectForKey: key];
				if (buttonId != nil) {
					RemoteControlEventIdentifier remoteControlEvent = (RemoteControlEventIdentifier)[buttonId intValue];
					[self sendRemoteButtonEvent: remoteControlEvent pressedDown: YES];
					[self sendRemoteButtonEvent: remoteControlEvent pressedDown: NO];
					return;
				}
				return;
			}
		}
		
		// let's see if a number of events are stored in the cookie string. this does
		// happen when the main thread is too busy to handle all incoming events in time.
		NSString* subCookieString;
		NSString* lastSubCookieString=nil;
		while( (subCookieString = [self validCookieSubstring: cookieString]) ) {
			cookieString = [cookieString substringFromIndex: [subCookieString length]];
			lastSubCookieString = subCookieString;
			if (_processesBacklog) {
				[self handleEventWithCookieString: subCookieString sumOfValues:sumOfValues];
			}
		}
		if (_processesBacklog == NO && lastSubCookieString != nil) {
			// process the last event of the backlog and assume that the button is not pressed down any longer.
			// The events in the backlog do not seem to be in order and therefore (in rare cases) the last event might be 
			// a button pressed down event while in reality the user has released it.
			// NSLog(@"processing last event of backlog");
			[self handleEventWithCookieString: lastSubCookieString sumOfValues:0];
		}
		if ([cookieString length] > 0) {
			NSLog(@"Unknown button for cookiestring %@", cookieString);
		}
	}
}

- (void) removeNotifcationObserver {
	NSDistributedNotificationCenter* defaultCenter = [NSDistributedNotificationCenter defaultCenter];
	[defaultCenter removeObserver:self name:FINISHED_USING_REMOTE_CONTROL_NOTIFICATION object:nil];
}

- (void) remoteControlAvailable:(NSNotification *)notification {
	(void)notification;
	[self removeNotifcationObserver];
	[self startListening: self];
}

@end

/*	Callback method for the device queue
Will be called for any event of any type (cookie) to which we subscribe
*/
static void QueueCallbackFunction(void* target, IOReturn result, void* refcon, void* sender) {
	(void)refcon;
	(void)sender;
	
	if (target == NULL) {
		NSLog(@"QueueCallbackFunction called with invalid target!");
		return;
	}
	
#if _isMRR
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
#elif _isARC
	@autoreleasepool
#endif
	
	{
		HIDRemoteControlDevice* remote = (_arcbridge HIDRemoteControlDevice*)target;
		IOHIDEventStruct event;
		AbsoluteTime 	 zeroTime = {0,0};
		NSMutableString* cookieString = [NSMutableString string];
		SInt32			 sumOfValues = 0;
		while (result == kIOReturnSuccess)
		{
			result = (*[remote queue])->getNextEvent([remote queue], &event, zeroTime, 0);
			if ( result != kIOReturnSuccess ) {
				continue;
			}
			
			//printf("%lu %d %p\n", (unsigned long)event.elementCookie, event.value, event.longValue);
			
			if (((unsigned long)event.elementCookie)!=5) {
				sumOfValues+=event.value;
				[cookieString appendString:[NSString stringWithFormat:@"%lu_", (unsigned long)event.elementCookie]];
			}
		}
		
		[remote handleEventWithCookieString: cookieString sumOfValues: sumOfValues];
	}
	
#if _isMRR
	[pool drain];
#endif
}

@implementation HIDRemoteControlDevice (IOKitMethods)

- (IOHIDDeviceInterface**) createInterfaceForDevice: (io_object_t) hidDevice {
	_hidDeviceInterface = NULL;
	
	io_name_t className;
	IOReturn ioReturnValue = IOObjectGetClass(hidDevice, className);
	
	if (ioReturnValue != kIOReturnSuccess) {
		NSLog(@"Error: Failed to get class name.");
		return NULL;
	}
	
	IOCFPlugInInterface** plugInInterface = NULL;
	SInt32 score = 0;
	ioReturnValue = IOCreatePlugInInterfaceForService(hidDevice,
													  kIOHIDDeviceUserClientTypeID,
													  kIOCFPlugInInterfaceID,
													  &plugInInterface,
													  &score);
	if (ioReturnValue == kIOReturnSuccess) {
		//Call a method of the intermediate plug-in to create the device interface
		HRESULT plugInResult = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID), (LPVOID) &_hidDeviceInterface);
		
		if (plugInResult != S_OK) {
			NSLog(@"Error: Couldn't create HID class device interface");
		}
		// Release
		if (plugInInterface) {
			(*plugInInterface)->Release(plugInInterface);
		}
	}
	return _hidDeviceInterface;
}

- (BOOL) initializeCookies {
	IOHIDDeviceInterface122** handle = (IOHIDDeviceInterface122**)_hidDeviceInterface;
	if (!handle || !(*handle)) {
		return NO;
	}
	
	// Copy all elements, since we're grabbing most of the elements
	// for this device anyway, and thus, it's faster to iterate them
	// ourselves. When grabbing only one or two elements, a matching
	// dictionary should be passed in here instead of NULL.
	
	CFArrayRef elements = NULL;
	IOReturn success = (*handle)->copyMatchingElements(handle, NULL, &elements);
	
	if ( (success == kIOReturnSuccess) && elements ) {
		_allCookies = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
		
		CFIndex elementsCount = CFArrayGetCount(elements);
		if (elementsCount > 0) {
			for (CFIndex idx = 0; idx < elementsCount; idx++) {
				CFDictionaryRef element = CFArrayGetValueAtIndex(elements, idx);
				
				// Get cookie
				CFNumberRef cookie = CFDictionaryGetValue(element, CFSTR(kIOHIDElementCookieKey));
				if (cookie == NULL || CFGetTypeID(cookie) != CFNumberGetTypeID()) {
					continue;
				}
				
				// Get usage
				CFNumberRef usage = CFDictionaryGetValue(element, CFSTR(kIOHIDElementUsageKey));
				if (usage == NULL || CFGetTypeID(usage) != CFNumberGetTypeID()) {
					continue;
				}
				
				// Get usage page
				CFNumberRef usagePage = CFDictionaryGetValue(element, CFSTR(kIOHIDElementUsagePageKey));
				if (usagePage == NULL || CFGetTypeID(usagePage) != CFNumberGetTypeID()) {
					continue;
				}
				
				CFArrayAppendValue(_allCookies, cookie);
			}
		}
		
		CFRelease(elements);
	} else {
		return NO;
	}
	
	return YES;
}

- (BOOL) openDevice {
	IOHIDOptionsType openMode = kIOHIDOptionsTypeNone;
	if ([self isOpenInExclusiveMode]) {
		openMode = kIOHIDOptionsTypeSeizeDevice;
	}
	IOReturn ioReturnValue = (*_hidDeviceInterface)->open(_hidDeviceInterface, openMode);
	
	if (ioReturnValue == KERN_SUCCESS) {
		_queue = (*_hidDeviceInterface)->allocQueue(_hidDeviceInterface);
		if (_queue) {
			HRESULT result = (*_queue)->create(_queue, 0, 12);	//depth: maximum number of elements in queue before oldest elements in queue begin to be lost.
			if (result == kIOReturnSuccess) {
				CFIndex cookiesCount = CFArrayGetCount(_allCookies);
				if (cookiesCount > 0) {
					for (CFIndex idx = 0; idx < cookiesCount; idx++) {
						CFNumberRef cookieRef = CFArrayGetValueAtIndex(_allCookies, idx);
						IOHIDElementCookie cookie; // Note: this is 32 bit in both 32 & 64 bit ABIs!
						CFNumberGetValue(cookieRef, kCFNumberSInt32Type, &cookie);
						(*_queue)->addElement(_queue, cookie, 0);
					}
				}
				
				// add callback for async events
				ioReturnValue = (*_queue)->createAsyncEventSource(_queue, &_eventSource);
				if (ioReturnValue == KERN_SUCCESS) {
					ioReturnValue = (*_queue)->setEventCallout(_queue,
															   QueueCallbackFunction,
															   (_arcbridge void *)(self),
															   NULL);
					if (ioReturnValue == KERN_SUCCESS) {
						CFRunLoopAddSource(CFRunLoopGetCurrent(), _eventSource, kCFRunLoopDefaultMode);
						
						//start data delivery to queue
						(*_queue)->start(_queue);
						return YES;
					} else {
						NSLog(@"Error when setting event callback");
					}
				} else {
					NSLog(@"Error when creating async event source");
				}
			} else {
				NSLog(@"Error when creating queue");
			}
		} else {
			NSLog(@"Error when opening device");
		}
	} else if (ioReturnValue == (IOReturn)0xE00002C5 /* kIOReturnExclusiveAccess */) {
		// Alas, the kIOReturnExclusiveAccess macro performs undefined bit shifts,
		// as warned by -Wshift-sign-overflow. At runtime, under UBSan, this can crash
		// so we hardcode the numeric value and cast. <rdar://12665902>
		
		// the device is used exclusive by another application
		
		// 1. we register for the FINISHED_USING_REMOTE_CONTROL_NOTIFICATION notification
		NSDistributedNotificationCenter* defaultCenter = [NSDistributedNotificationCenter defaultCenter];
		[defaultCenter addObserver:self selector:@selector(remoteControlAvailable:) name:FINISHED_USING_REMOTE_CONTROL_NOTIFICATION object:nil];
		
		// 2. send a distributed notification that we wanted to use the remote control
		[[self class] sendRequestForRemoteControlNotification];
	}
	return NO;
}

@end

