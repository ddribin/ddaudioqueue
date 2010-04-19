//

#import <Cocoa/Cocoa.h>
#import "DDAudioBufferQueue.h"

@class DDAudioBufferQueue;
@class DDAudioBuffer;

@interface RunLoopSourceAppDelegate : NSObject <NSApplicationDelegate, DDAudioQueueDelegate> {
    NSWindow *window;
    DDAudioBufferQueue * _audioQueue;
    DDAudioBuffer * _activeBuffer;
    int _counter;
}

@property (assign) IBOutlet NSWindow *window;

@end
