/*****************************************************************************
 * MultiClickRemoteBehavior.m
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

#import "MultiClickRemoteBehavior.h"

const NSTimeInterval DEFAULT_MAXIMUM_CLICK_TIME_DIFFERENCE=0.35;
const NSTimeInterval HOLD_RECOGNITION_TIME_INTERVAL=0.4;

@implementation MultiClickRemoteBehavior

- (id) init {
	if (self = [super init]) {
		_maxClickTimeDifference = DEFAULT_MAXIMUM_CLICK_TIME_DIFFERENCE;
	}
	return self;
}

// Delegates are not retained!
// http://developer.apple.com/documentation/Cocoa/Conceptual/CocoaFundamentals/CommunicatingWithObjects/chapter_6_section_4.html
// Delegating objects do not (and should not) retain their delegates. 
// However, clients of delegating objects (applications, usually) are responsible for ensuring that their delegates are around
// to receive delegation messages. To do this, they may have to retain the delegate.
- (void) setDelegate: (id<MultiClickRemoteBehaviorDelegate>) inDelegate {
	if (inDelegate && [inDelegate respondsToSelector:@selector(remoteButton:pressedDown:clickCount:)]==NO) return;
	
	_delegate = inDelegate;
}
- (id<MultiClickRemoteBehaviorDelegate>) delegate {
	return _delegate;
}

- (BOOL) simulateHoldEvent {
	return _simulateHoldEvents;
}
- (void) setSimulateHoldEvent: (BOOL) value {
	_simulateHoldEvents = value;
}

- (BOOL) simulatesHoldForButtonIdentifier: (RemoteControlEventIdentifier) identifier remoteControl: (RemoteControl*) remoteControl {
	// we do that check only for the normal button identifiers as we would check for hold support for hold events instead
	if (identifier > (1 << EVENT_TO_HOLD_EVENT_OFFSET)) return NO; 
	
	return [self simulateHoldEvent] && [remoteControl sendsEventForButtonIdentifier: (identifier << EVENT_TO_HOLD_EVENT_OFFSET)]==NO;
}

- (BOOL) clickCountingEnabled {
	return _clickCountEnabledButtons != 0;
}
- (void) setClickCountingEnabled: (BOOL) value {
	if (value) {
		[self setClickCountEnabledButtons: kRemoteButtonPlus | kRemoteButtonMinus | kRemoteButtonPlay | kRemoteButtonLeft | kRemoteButtonRight | kRemoteButtonMenu];
	} else {
		[self setClickCountEnabledButtons: 0];
	}
}

- (unsigned int) clickCountEnabledButtons {
	return _clickCountEnabledButtons;
}
- (void) setClickCountEnabledButtons: (unsigned int)value {
	_clickCountEnabledButtons = value;
}

- (NSTimeInterval) maximumClickCountTimeDifference {
	return _maxClickTimeDifference;
}
- (void) setMaximumClickCountTimeDifference: (NSTimeInterval) timeDiff {
	_maxClickTimeDifference = timeDiff;
}

- (void) sendPressedDownEventToMainThread: (NSNumber*) event {
	[_delegate remoteButton:[event intValue] pressedDown:YES clickCount:1];
}

- (void) sendSimulatedHoldEvent: (id) time {
	BOOL startSimulateHold = NO;
	RemoteControlEventIdentifier event = _lastHoldEvent;
	@synchronized(self) {
		startSimulateHold = (_lastHoldEvent>0 && _lastHoldEventTime == [time doubleValue]);
	}
	if (startSimulateHold) {
		_lastEventSimulatedHold = YES;
		event = (event << EVENT_TO_HOLD_EVENT_OFFSET);
		[self performSelectorOnMainThread:@selector(sendPressedDownEventToMainThread:) withObject:[NSNumber numberWithInt:event] waitUntilDone:NO];
	}
}

- (void) executeClickCountEvent: (NSArray*) values {
	RemoteControlEventIdentifier event = [[values objectAtIndex: 0] unsignedIntValue]; 
	NSTimeInterval eventTimePoint = [[values objectAtIndex: 1] doubleValue];
	
	BOOL finishedClicking = NO;
	int finalClickCount = _eventClickCount;	
	
	@synchronized(self) {
		finishedClicking = (event != _lastClickCountEvent || eventTimePoint == _lastClickCountEventTime);
		if (finishedClicking) {
			_eventClickCount = 0;		
			_lastClickCountEvent = 0;
			_lastClickCountEventTime = 0;
		}
	}
	
	if (finishedClicking) {	
		[_delegate remoteButton:event pressedDown: YES clickCount:finalClickCount];		
		// trigger a button release event, too
		[NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow:0.1]];
		[_delegate remoteButton:event pressedDown: NO clickCount:finalClickCount];
	}
}

- (void) sendRemoteButtonEvent: (RemoteControlEventIdentifier) event pressedDown: (BOOL) pressedDown remoteControl: (RemoteControl*) remoteControl {	
	if (!_delegate)  return;
	
	BOOL clickCountingForEvent = ([self clickCountEnabledButtons] & event) == event;

	if ([self simulatesHoldForButtonIdentifier: event remoteControl: remoteControl] && _lastClickCountEvent==0) {
		if (pressedDown) {
			// wait to see if it is a hold
			_lastHoldEvent = event;
			_lastHoldEventTime = [NSDate timeIntervalSinceReferenceDate];
			[self performSelector:@selector(sendSimulatedHoldEvent:) 
					   withObject:[NSNumber numberWithDouble:_lastHoldEventTime]
					   afterDelay:HOLD_RECOGNITION_TIME_INTERVAL];
			return;
		} else {
			if (_lastEventSimulatedHold) {
				// it was a hold
				// send an event for "hold release"
				event = (event << EVENT_TO_HOLD_EVENT_OFFSET);
				_lastHoldEvent = 0;
				_lastEventSimulatedHold = NO;

				[_delegate remoteButton:event pressedDown: pressedDown clickCount:1];
				return;
			} else {
				RemoteControlEventIdentifier previousEvent = _lastHoldEvent;
				@synchronized(self) {
					_lastHoldEvent = 0;
				}						
				
				// in case click counting is enabled we have to setup the state for that, too
				if (clickCountingForEvent) {
					_lastClickCountEvent = previousEvent;
					_lastClickCountEventTime = _lastHoldEventTime;
					NSNumber* eventNumber;
					NSNumber* timeNumber;		
					_eventClickCount = 1;
					timeNumber = [NSNumber numberWithDouble:_lastClickCountEventTime];
					eventNumber= [NSNumber numberWithUnsignedInt:previousEvent];
					NSTimeInterval diffTime = _maxClickTimeDifference-([NSDate timeIntervalSinceReferenceDate]-_lastHoldEventTime);
					[self performSelector: @selector(executeClickCountEvent:) 
							   withObject: [NSArray arrayWithObjects:eventNumber, timeNumber, nil]
							   afterDelay: diffTime];							
					// we do not return here because we are still in the press-release event
					// that will be consumed below
				} else {
					// trigger the pressed down event that we consumed first
					[_delegate remoteButton:event pressedDown: YES clickCount:1];							
				}
			}										
		}
	}
	
	if (clickCountingForEvent) {
		if (pressedDown == NO) return;

		NSNumber* eventNumber;
		NSNumber* timeNumber;
		@synchronized(self) {
			_lastClickCountEventTime = [NSDate timeIntervalSinceReferenceDate];
			if (_lastClickCountEvent == event) {
				_eventClickCount = _eventClickCount + 1;
			} else {
				_eventClickCount = 1;
			}
			_lastClickCountEvent = event;
			timeNumber = [NSNumber numberWithDouble:_lastClickCountEventTime];
			eventNumber= [NSNumber numberWithUnsignedInt:event];
		}
		[self performSelector: @selector(executeClickCountEvent:) 
				   withObject: [NSArray arrayWithObjects:eventNumber, timeNumber, nil]
				   afterDelay: _maxClickTimeDifference];
	} else {
		[_delegate remoteButton:event pressedDown: pressedDown clickCount:1];
	}		

}

@end
