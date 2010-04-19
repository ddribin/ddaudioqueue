//

#import "DDAudioBufferQueue.h"
#import "DDAudioBuffer.h"


@implementation DDAudioBufferQueue

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _delegate = delegate;
    _buffers = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [self removeFromRunLoop];
    [self reset];
    [_buffers release];
    [super dealloc];
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

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
{
    NSAssert(_runLoop == NULL, @"Already scheduled in a run loop");
    
    CFRunLoopSourceContext sourceContext = {0};
    sourceContext.info = self;
    sourceContext.perform = MyPerformCallback;
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    _runLoop = [runLoop getCFRunLoop];
    CFRetain(_runLoop);
    CFRunLoopAddSource(_runLoop, _runLoopSource, (CFStringRef)mode);
}

- (void)removeFromRunLoop;
{
    if (_runLoop == NULL) {
        return;
    }
    
    CFRunLoopSourceInvalidate(_runLoopSource);
    CFRelease(_runLoopSource);
    _runLoopSource = NULL;
    CFRelease(_runLoop);
    _runLoop = NULL;
}

- (void)popAllFromList:(RAAtomicListRef *)list
{
	while (RAAtomicListPop(list)) {
    }
}

- (void)reset;
{
    [self popAllFromList:&_bufferList];
    [self popAllFromList:&_renderList];
    [self popAllFromList:&_availableList];
}

- (DDAudioBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;
{
    DDAudioBuffer * buffer = [[(DDAudioBuffer *)[DDAudioBuffer alloc] initWithCapacity:capacity] autorelease];
    [_buffers addObject:buffer];
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
