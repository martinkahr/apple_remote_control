#import "RemoteFeedbackView.h"
#import "AppleRemote.h"

@implementation RemoteFeedbackView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		remoteImage = [[NSImage imageNamed:@"AppleRemote"] retain];
		lastButtonIdentifier = -1;
	}
	return self;
}

- (void) dealloc {

	[remoteImage release];
	[super dealloc];
}

- (void) clearAfterRedraw: (id) sender {
	lastButtonIdentifier = -1;
	[self setNeedsDisplay:YES];
}

- (void) remoteButton: (RemoteControlEventIdentifier)buttonIdentifier pressedDown: (BOOL) pressedDown clickCount: (unsigned int)clickCount {
	if (pressedDown) {
		lastButtonIdentifier = buttonIdentifier;
	} else {
		if (drawn) {
			lastButtonIdentifier = -1;
		} else {
			lastButtonIdentifier = buttonIdentifier;
			[self performSelector:@selector(clearAfterRedraw:) withObject:self afterDelay:0.1];
		}
	}
		
	drawn = NO;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
	drawn = YES;
	NSRect imageRect;
	NSRect drawingRect;
	imageRect.origin = NSZeroPoint;
	imageRect.size   = [remoteImage size];
	
	int x = ([self bounds].size.width  - [remoteImage size].width)/2;
	int y = ([self bounds].size.height - [remoteImage size].height)/2;
	
	drawingRect.origin = NSMakePoint(x, y);
	drawingRect.size   = imageRect.size;
	
	[remoteImage drawInRect: drawingRect
				   fromRect: imageRect
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
	
	if (lastButtonIdentifier == -1) {
		return;
	}
	
	RemoteControlEventIdentifier buttonToSelect = lastButtonIdentifier;
	
	NSPoint buttonPos;
	float opacity = 0.5;
	
	switch(buttonToSelect) {
		case kRemoteButtonPlus_Hold:
			opacity = 0.8;			
			buttonPos.x = 53;
			buttonPos.y = 240;
			break;
		case kRemoteButtonPlus:
			buttonPos.x = 53;
			buttonPos.y = 240;
			break;
		case kRemoteButtonMinus_Hold:
			opacity = 0.8;						
			buttonPos.x = 53;
			buttonPos.y = 180;
			break;
		case kRemoteButtonMinus:
			buttonPos.x = 53;
			buttonPos.y = 180;			
			break;
		case kRemoteButtonMenu_Hold:
			opacity = 0.8;			
			buttonPos.x = 53;
			buttonPos.y = 137;
			break;
		case kRemoteButtonMenu:
			buttonPos.x = 53;
			buttonPos.y = 137;
			break;			
		case kRemoteButtonPlay_Hold:
			buttonPos.x = 53;
			buttonPos.y = 210;
			opacity = 0.8;
			break;
		case kRemoteButtonPlay:
			buttonPos.x = 53;
			buttonPos.y = 210;			
			break;
		case kRemoteButtonRight_Hold:
			opacity = 0.8;
			buttonPos.x = 83;
			buttonPos.y = 210;	
			break;
		case kRemoteButtonRight:
			buttonPos.x = 83;
			buttonPos.y = 210;	
			break;
		case kRemoteButtonLeft_Hold:
			opacity = 0.8;			
			buttonPos.x = 23;
			buttonPos.y = 210;
			break;
		case kRemoteButtonLeft:
			buttonPos.x = 23;
			buttonPos.y = 210;
			break;
		default:
			break;
	}
	
	float width = 20.0;
	float height= 20.0;
    NSRect r = NSMakeRect(buttonPos.x + x - (width/2), buttonPos.y + y - (height/2), width, height);
    NSBezierPath* bp = [NSBezierPath bezierPathWithOvalInRect:r];
	
	[[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:opacity] set];
    [bp fill];	
}

@end
