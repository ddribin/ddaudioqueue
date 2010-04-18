//
//  DDAudioBufferQueue.m
//  RunLoopSource
//
//  Created by Dave Dribin on 4/17/10.
//  Copyright 2010 Bit Maki, Inc.. All rights reserved.
//

#import "DDAudioBufferQueue.h"


@implementation DDAudioBuffer

- (id)initWithCapacity:(NSUInteger)capacity;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    NSString * identifierString = [NSString stringWithFormat:@"%@-%p", [self class], self];
    _identifier = [[identifierString dataUsingEncoding:NSUTF8StringEncoding] retain];
    _data = [[NSMutableData alloc] initWithLength:capacity];
    
    _audioDataBytesCapacity = capacity;
    _audioData = [_data mutableBytes];
    _audioDataByteSize = capacity;
    _userData = NULL;
    
    DDAudioReadBuffer readBuffer = {
        .audioDataCapacity = capacity,
        .audioData = [_data bytes],
        .userData = NULL,
    };
    memcpy(&_readBuffer, &readBuffer, sizeof(DDAudioReadBuffer));
    
    return self;
}

- (void) dealloc
{
    [_data release];
    [_identifier release];
    [super dealloc];
}

- (NSData *)identifier;
{
    return _identifier;
}

- (NSMutableData *)data;
{
    return _data;
}

void DDAudioBufferGetReadBuffer(DDAudioBuffer * buffer, DDAudioReadBuffer * readBuffer)
{
    DDAudioReadBuffer readBufferCopy = {
        .audioDataCapacity = buffer->_audioDataBytesCapacity,
        .audioData = buffer->_audioData,
        .userData = NULL,
    };
    memcpy(readBuffer, &readBufferCopy, sizeof(DDAudioReadBuffer));
}

static void DDAudioBufferSend(DDAudioBuffer * buffer, CFMessagePortRef messagePort)
{
    CFMessagePortSendRequest(messagePort, 300, (CFDataRef)buffer->_identifier,
                             1, 1, NULL, NULL);
}

static void DDAudioBufferProcess(DDAudioBuffer * buffer)
{
    NSLog(@"Processing buffer: %@ %@", buffer, [buffer data]);
}

@end

@implementation DDAudioBufferQueue

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _delegate = delegate;
    _buffers = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)bufferWithIdentifierIsAvailable:(NSData *)identifier
{
    DDAudioBuffer * buffer = [_buffers objectForKey:identifier];
    [self->_delegate audioQueue:self bufferIsAvailable:buffer];
}

static CFDataRef MyCallBack (CFMessagePortRef local,
                             SInt32 msgid,
                             CFDataRef data,
                             void *info)
{
    DDAudioBufferQueue * self = info;
    [self bufferWithIdentifierIsAvailable:(id)data];
    return NULL;
}

- (BOOL)start:(NSError **)error;
{
    CFMessagePortContext context = {
        .version = 0,
        .info = self,
        .retain = NULL,
        .release = NULL,
        .copyDescription = NULL,
    };
    NSString * name = [NSString stringWithFormat:@"%@-%p", [self className], self];
    _messagePort = CFMessagePortCreateLocal(NULL,
                                            (CFStringRef)name,
                                            MyCallBack,
                                            &context,
                                            NULL);
    _messagePortSource = CFMessagePortCreateRunLoopSource(NULL,
                                                          _messagePort,
                                                          0);
    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(cfRunLoop, _messagePortSource, kCFRunLoopCommonModes);
    [NSThread detachNewThreadSelector:@selector(threadEntry) toTarget:self withObject:nil];
    return YES;
}

static DDAudioBuffer * __activeBuffer;

static void processActiveBuffer(DDAudioBufferQueue * queue)
{
    DDAudioReadBuffer readBuffer;
    DDAudioBufferGetReadBuffer(__activeBuffer, &readBuffer);
    NSLog(@"Processing %u data at %p 0x%02x", readBuffer.audioDataCapacity, readBuffer.audioData,
          *(uint8_t*)readBuffer.audioData);
}

static void MyRenderer(void * context, void * outputData)
{
    DDAudioBufferQueue * queue = (DDAudioBufferQueue *)context;
    if (__activeBuffer != nil) {
        processActiveBuffer(queue);
        [__activeBuffer autorelease];
        DDAudioQueueBufferIsAvailable(queue, __activeBuffer);
        __activeBuffer = nil;
    }
    else {
        __activeBuffer = DDAudioQueueDequeueBuffer(queue);
        if (__activeBuffer != nil) {
            processActiveBuffer(queue);
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

- (void)stop;
{
}

- (DDAudioBuffer *)allocateBufferWithSize:(NSUInteger)size error:(NSError **)error;
{
    DDAudioBuffer * buffer = [[(DDAudioBuffer *)[DDAudioBuffer alloc] initWithCapacity:size] autorelease];
    [_buffers setObject:buffer forKey:[buffer identifier]];
    return buffer;
}

- (BOOL)enqueueBuffer:(DDAudioBuffer *)buffer;
{
    NSLog(@"enqueueBuffer: %@ %p %@", buffer, [[buffer data] mutableBytes], [buffer data]);
    RAAtomicListInsert(&_bufferList, buffer);
    return YES;
}

DDAudioBuffer * DDAudioQueueDequeueBuffer(DDAudioBufferQueue * queue)
{
    DDAudioBuffer * buffer = (id)RAAtomicListPop(&queue->_renderList);
    if (buffer == nil) {
        queue->_renderList = RAAtomicListSteal(&queue->_bufferList);
        RAAtomicListReverse(&queue->_renderList);
        buffer = (id)RAAtomicListPop(&queue->_renderList);
    }
    return buffer;
}

void DDAudioQueueBufferIsAvailable(DDAudioBufferQueue * queue, DDAudioBuffer * buffer)
{
    DDAudioBufferSend(buffer, queue->_messagePort);
}

@end
