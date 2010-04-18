//
//  RunLoopSourceAppDelegate.m
//  RunLoopSource
//
//  Created by Dave Dribin on 4/17/10.
//  Copyright 2010 Bit Maki, Inc.. All rights reserved.
//

#import "RunLoopSourceAppDelegate.h"
#import "DDAudioBufferQueue.h"

@implementation RunLoopSourceAppDelegate

@synthesize window;

static CFDataRef MyCallBack (CFMessagePortRef local,
                      SInt32 msgid,
                      CFDataRef data,
                      void *info)
{
    NSLog(@"Received data: %@", data);
    return NULL;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
#if 0
    _poker = [[DDRunLoopPoker alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(3);
        [_poker pokeRunLoop];
        sleep(3);
    });
#endif
    
#if 0
    CFMessagePortContext context = {
        .version = 0,
        .info = self,
        .retain = NULL,
        .release = NULL,
        .copyDescription = NULL,
    };
    CFMessagePortRef messagePort = CFMessagePortCreateLocal(NULL,
                                                            (CFStringRef)@"MyName",
                                                            MyCallBack,
                                                            &context,
                                                            NULL);
    CFRunLoopSourceRef messagePortSource = CFMessagePortCreateRunLoopSource(NULL,
                                                                            messagePort,
                                                                            0);
    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(cfRunLoop, messagePortSource, (CFStringRef)NSDefaultRunLoopMode);
    CFRunLoopAddSource(cfRunLoop, messagePortSource, (CFStringRef)NSModalPanelRunLoopMode);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(3);
        NSData * data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
        CFMessagePortSendRequest(messagePort, 300, (CFDataRef)data,
                                 1, 1, NULL, NULL);
        sleep(3);
    });
#endif
    
    _audioQueue = [[DDAudioBufferQueue alloc] initWithDelegate:self];
               
    [_audioQueue scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [NSThread detachNewThreadSelector:@selector(threadEntry) toTarget:self withObject:nil];
    
    sleep(2);
    
    for (int i = 0; i < 3; i++) {
        DDAudioBuffer * buffer = [_audioQueue allocateBufferWithCapacity:4 error:NULL];
        memset(buffer.bytes, _counter, buffer.capacity);
        buffer.length = buffer.capacity;
        [_audioQueue enqueueBuffer:buffer];
        _counter++;
    }
}

- (void)audioQueue:(DDAudioBufferQueue *)queue bufferIsAvailable:(DDAudioBuffer *)buffer;
{
    NSLog(@"bufferIsAvailable: %@ %p <0x%08x>", buffer, buffer.bytes, *(uint32_t *)buffer.bytes);
    memset(buffer.bytes, _counter, buffer.capacity);
    buffer.length = buffer.capacity;
    [_audioQueue enqueueBuffer:buffer];
    _counter++;
}

static void processBuffer(DDAudioBuffer * buffer, DDAudioBufferQueue * queue)
{
    const void * bytes = DDAudioBufferBytes(buffer);
    NSUInteger length = DDAudioBufferLength(buffer);
    NSLog(@"Processing %u data at %p <0x%08X>", length, bytes, *(uint32_t*)bytes);
}

static void MyRenderer(void * context, void * outputData)
{
    RunLoopSourceAppDelegate * self = context;
    DDAudioBufferQueue * queue = self->_audioQueue;
    if (self->_activeBuffer != nil) {
        processBuffer(self->_activeBuffer, queue);
        DDAudioQueueBufferIsAvailable(queue, self->_activeBuffer);
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
    
    while (YES) {
        MyRenderer(self, NULL);
        [NSThread sleepForTimeInterval:1.0];
    }
    
    [pool drain];
}


@end
