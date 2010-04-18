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
    _capacity = capacity;
    _bytes = [_data mutableBytes];
    _length = 0;
    
    return self;
}

- (void) dealloc
{
    [_data release];
    [_identifier release];
    [super dealloc];
}

- (NSUInteger)capacity;
{
    return _capacity;
}

- (void *)bytes;
{
    return _bytes;
}

- (NSUInteger)length;
{
    return _length;
}

- (void)setLength:(NSUInteger)length;
{
    _length = length;
}

- (NSData *)identifier;
{
    return _identifier;
}

const void * DDAudioBufferBytes(DDAudioBuffer * buffer)
{
    return buffer->_bytes;
}

NSUInteger DDAudioBufferLength(DDAudioBuffer * buffer)
{
    return buffer->_length;
}

@end

@implementation DDAudioBufferQueue

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _delegate = delegate;
    _buffers = [[NSMutableArray alloc] init];
    _buffersByIdentifier = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)sendAvaialableBuffersToDelegate;
{
    DDAudioBuffer * buffer = NULL;
    do {
        buffer = RAAtomicListPop(&_availableList);
        if (buffer != NULL) {
            buffer.length = 0;
            [self->_delegate audioQueue:self bufferIsAvailable:buffer];
        }
    } while (buffer != NULL);
}

static void MyPerformCallback(void * info)
{
    DDAudioBufferQueue * self = info;
    [self sendAvaialableBuffersToDelegate];
}

- (BOOL)start:(NSError **)error;
{
    CFRunLoopSourceContext sourceContext = {0};
    sourceContext.info = self;
    sourceContext.perform = MyPerformCallback;
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    _runLoop = CFRunLoopGetCurrent();
    CFRetain(_runLoop);
    CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);
    
    [NSThread detachNewThreadSelector:@selector(threadEntry) toTarget:self withObject:nil];
    return YES;
}

static DDAudioBuffer * __activeBuffer;

static void processActiveBuffer(DDAudioBufferQueue * queue)
{
    const void * bytes = DDAudioBufferBytes(__activeBuffer);
    NSUInteger length = DDAudioBufferLength(__activeBuffer);
    NSLog(@"Processing %u data at %p <0x%08X>", length, bytes, *(uint32_t*)bytes);
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

- (void)reset;
{
}

- (DDAudioBuffer *)allocateBufferWithSize:(NSUInteger)size error:(NSError **)error;
{
    DDAudioBuffer * buffer = [[(DDAudioBuffer *)[DDAudioBuffer alloc] initWithCapacity:size] autorelease];
    [_buffers addObject:buffer];
    [_buffersByIdentifier setObject:buffer forKey:[buffer identifier]];
    return buffer;
}

- (BOOL)enqueueBuffer:(DDAudioBuffer *)buffer;
{
    NSLog(@"enqueueBuffer: %@ %p <0x%08X>", buffer, buffer.bytes, *(uint32_t *)buffer.bytes);
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
    RAAtomicListInsert(&queue->_availableList, buffer);
    CFRunLoopSourceSignal(queue->_runLoopSource);
    CFRunLoopWakeUp(queue->_runLoop);
}

@end
