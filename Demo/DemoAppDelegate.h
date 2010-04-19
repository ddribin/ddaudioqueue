//

#import <Cocoa/Cocoa.h>
#import "DDAudioQueue.h"

@class DDAudioQueue;
@class DDAudioQueueBuffer;

@interface DemoAppDelegate : NSObject <NSApplicationDelegate, DDAudioQueueDelegate>
{
    NSWindow *window;
    DDAudioQueue * _audioQueue;
    DDAudioQueueBuffer * _activeBuffer;
    int _counter;
}

@property (assign) IBOutlet NSWindow *window;

@end
