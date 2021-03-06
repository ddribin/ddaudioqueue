//

#import "DemoAppDelegate.h"
#import "DDAudioQueue.h"
#import "DDAudioQueueBuffer.h"

@implementation DemoAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    _audioQueue = [[DDAudioQueue alloc] initWithDelegate:self];
               
    [_audioQueue scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [NSThread detachNewThreadSelector:@selector(threadEntry) toTarget:self withObject:nil];
    
    sleep(2);
    
    for (int i = 0; i < 3; i++) {
        DDAudioQueueBuffer * buffer = [_audioQueue allocateBufferWithCapacity:4 error:NULL];
        memset(buffer->bytes, _counter, buffer->capacity);
        buffer->length = buffer->capacity;
        [_audioQueue enqueueBuffer:buffer];
        _counter++;
    }
}

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;
{
    NSLog(@"bufferIsAvailable: %@ %p <0x%08x>", buffer, buffer->bytes, *(uint32_t *)buffer->bytes);
    memset(buffer->bytes, _counter, buffer->capacity);
    buffer->length = buffer->capacity;
    [_audioQueue enqueueBuffer:buffer];
    _counter++;
}

static void processBuffer(DDAudioQueueBuffer * buffer, DDAudioQueue * queue)
{
    const void * bytes = buffer->bytes;
    NSUInteger length = buffer->length;
    NSLog(@"Processing %u data at %p <0x%08X>", length, bytes, *(uint32_t*)bytes);
}

static void MyRenderer(void * context, void * outputData)
{
    DemoAppDelegate * self = context;
    DDAudioQueue * queue = self->_audioQueue;
    if (self->_activeBuffer != nil) {
        processBuffer(self->_activeBuffer, queue);
        DDAudioQueueMakeBufferAvailable(queue, self->_activeBuffer);
        self->_activeBuffer = nil;
    }
    else {
        self->_activeBuffer = DDAudioQueueDequeueBuffer(queue);
        if (self->_activeBuffer != nil) {
            processBuffer(self->_activeBuffer, queue);
        } else {
            NSLog(@"Processing silence");
        }
    }
}

- (void)threadEntry
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    while (_counter <= 5) {
        MyRenderer(self, NULL);
        [NSThread sleepForTimeInterval:1.0];
    }
    
    [self performSelectorOnMainThread:@selector(threadFinished) withObject:nil waitUntilDone:NO];
    
    [pool drain];
}

- (void)threadFinished
{
    NSLog(@"Thread finished");
    [_audioQueue removeFromRunLoop];
    [_audioQueue reset];
    [_audioQueue release];
    _audioQueue = nil;
}


@end
