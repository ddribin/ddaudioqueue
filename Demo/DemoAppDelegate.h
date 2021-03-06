//

#import <Cocoa/Cocoa.h>
#import "DDAudioQueueDelegate.h"

@class DDAudioQueue;

@interface DemoAppDelegate : NSObject <NSApplicationDelegate, DDAudioQueueDelegate>
{
    NSWindow *window;
    DDAudioQueue * _audioQueue;
    DDAudioQueueBuffer * _activeBuffer;
    int _counter;
}

@property (assign) IBOutlet NSWindow *window;

@end
