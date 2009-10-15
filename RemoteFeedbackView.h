/* RemoteFeedbackView */

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
