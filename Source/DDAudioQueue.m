//

#import "DDAudioQueue.h"
#import "DDAudioQueueDelegate.h"
#import "DDAudioQueueBuffer.h"

typedef struct DDAudioQueueListNode
{
    DDAudioQueueBuffer buffer;
    struct DDAudioQueueListNode * next;
} DDAudioQueueListNode;

#define NODE_OFFSET offsetof(DDAudioQueueListNode, next)

#define _COMPILE_ASSERT_SYMBOL_INNER(line, msg) __COMPILE_ASSERT_ ## line ## __ ## msg
#define _COMPILE_ASSERT_SYMBOL(line, msg) _COMPILE_ASSERT_SYMBOL_INNER(line, msg)
#define COMPILE_ASSERT(test, msg) \
  typedef char _COMPILE_ASSERT_SYMBOL(__LINE__, msg) [ ((test) ? 1 : -1) ]

COMPILE_ASSERT(offsetof(DDAudioQueueListNode, buffer) == 0, invalid_node_offset);

@implementation DDAudioQueue

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _delegate = delegate;
    _buffers = [[NSMutableArray alloc] init];
    _mallocData = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc
{
    [self removeFromRunLoop];
    [self reset];
    [_buffers release];
    [super dealloc];
}

#if 0
- (void)sendAvaialableBuffersToDelegate;
{
    DDAudioQueueBuffer * buffer = NULL;
    do {
        buffer = RAAtomicListPop(&_availableList);
        if (buffer != NULL) {
            buffer.length = 0;
            [self->_delegate audioQueue:self bufferIsAvailable:buffer];
        }
    } while (buffer != NULL);
}
#else
- (void)sendAvaialableBuffersToDelegate;
{
    DDAudioQueueBuffer * buffer = NULL;
    do {
        buffer = DDAtomicListPop(&_availableList2, NODE_OFFSET);
        if (buffer != NULL) {
            buffer->length = 0;
            [self->_delegate audioQueue:self bufferIsAvailable:buffer];
        }
    } while (buffer != NULL);
}
#endif

static void MyPerformCallback(void * info)
{
    DDAudioQueue * self = info;
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

#if 0
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
#else
- (void)popAllFromList:(DDAtomicListRef *)list
{
	while (DDAtomicListPop(list, NODE_OFFSET)) {
    }
}

- (void)reset;
{
    [self popAllFromList:&_bufferList2];
    [self popAllFromList:&_renderList2];
    [self popAllFromList:&_availableList2];
}
#endif

#if 0
- (DDAudioQueueBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;
{
    DDAudioQueueBuffer * buffer = [[(DDAudioQueueBuffer *)[DDAudioQueueBuffer alloc] initWithCapacity:capacity] autorelease];
    [_buffers addObject:buffer];
    
    return buffer;
}

- (BOOL)enqueueBuffer:(DDAudioQueueBuffer *)buffer;
{
    NSAssert(buffer != nil, @"Buffer must not be nil");
    RAAtomicListInsert(&_bufferList, buffer);
    return YES;
}
#endif

- (void *)malloc:(size_t)size
{
    NSMutableData * data = [NSMutableData dataWithLength:size];
    void * bytes = [data mutableBytes];
    NSValue * bytesValue = [NSValue valueWithPointer:bytes];
    [_mallocData setObject:data forKey:bytesValue];
    return bytes;
}

- (void)free:(void *)bytes
{
    NSValue * bytesValue = [NSValue valueWithPointer:bytes];
    [_mallocData removeObjectForKey:bytesValue];
}

- (DDAudioQueueBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;
{
    DDAudioQueueListNode * node = [self malloc:sizeof(DDAudioQueueListNode)];
    void * bufferBytes = [self malloc:capacity];
    
    // Can only assign capacity and bytes on creation because they're const.
    // Can't create and assign dynamic memory, so cheat by creating
    // a temporary one on the stack and memcpy it to our malloc'd node.
    DDAudioQueueBuffer buffer = {
        .capacity = capacity,
        .length = 0,
        .bytes = bufferBytes,
    };
    memcpy(&node->buffer, &buffer, sizeof(buffer));
    
    DDAudioQueueBuffer * buffer2 = &node->buffer;
    NSAssert(node == (void *)buffer2, @"Invalid node layout");
    
    return buffer2;
}

- (void)deallocateBuffer:(DDAudioQueueBuffer *)buffer;
{
    [self free:buffer->bytes];
    [self free:buffer];
}

- (BOOL)enqueueBuffer:(DDAudioQueueBuffer *)buffer;
{
    NSAssert(buffer != nil, @"Buffer must not be nil");
    DDAudioQueueListNode * node = (DDAudioQueueListNode *)buffer;
    DDAtomicListInsert(&_bufferList2, node, NODE_OFFSET);
    return YES;
}

#if 0
DDAudioQueueBuffer * DDAudioQueueDequeueBuffer(DDAudioQueue * queue)
{
    DDAudioQueueBuffer * buffer = (id)RAAtomicListPop(&queue->_renderList);
    if (buffer == nil) {
        queue->_renderList = RAAtomicListSteal(&queue->_bufferList);
        RAAtomicListReverse(&queue->_renderList);
        buffer = (id)RAAtomicListPop(&queue->_renderList);
    }
    return buffer;
}

void DDAudioQueueMakeBufferAvailable(DDAudioQueue * queue, DDAudioQueueBuffer * buffer)
{
    RAAtomicListInsert(&queue->_availableList, buffer);
    CFRunLoopSourceSignal(queue->_runLoopSource);
    CFRunLoopWakeUp(queue->_runLoop);
}
#else
DDAudioQueueBuffer * DDAudioQueueDequeueBuffer(DDAudioQueue * queue)
{
    DDAudioQueueBuffer * buffer = DDAtomicListPop(&queue->_renderList2, NODE_OFFSET);
    if (buffer == nil) {
        queue->_renderList2 = DDAtomicListSteal(&queue->_bufferList2);
        DDAtomicListReverse(&queue->_renderList2, NODE_OFFSET);
        buffer = DDAtomicListPop(&queue->_renderList2, NODE_OFFSET);
    }
    return buffer;
}

void DDAudioQueueMakeBufferAvailable(DDAudioQueue * queue, DDAudioQueueBuffer * buffer)
{
    DDAtomicListInsert(&queue->_availableList2, buffer, NODE_OFFSET);
    CFRunLoopSourceSignal(queue->_runLoopSource);
    CFRunLoopWakeUp(queue->_runLoop);
}
#endif

@end
