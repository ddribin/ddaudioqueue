//

#import "DDAudioQueue.h"
#import "DDAudioQueueDelegate.h"
#import "DDAudioQueueBuffer.h"

/*
 * Play a little trick here. By putting the buffer as the first element in the
 * structure, assume we can just cast a pointer to a buffer and node and
 * vice versa.  If padding somehow got in front of buffer, this wouldn't work.
 */
typedef struct DDAudioQueueListNode
{
    DDAudioQueueBuffer buffer;
    struct DDAudioQueueListNode * next;
} DDAudioQueueListNode;

#define NODE_OFFSET offsetof(DDAudioQueueListNode, next)

static DDAudioQueueListNode sFenceNode = {
    .buffer = {
        .capacity = 0,
        .length = 0,
        .bytes = NULL,
    },
    .next = NULL,
};
DDAudioQueueBuffer * DDAudioQueueFenceBuffer = &sFenceNode.buffer;

static void MyPerformCallback(void * info);

@interface DDAudioQueue ()
- (void)callDelegateForAvailableBuffers;
- (void)callDelegateForBuffer:(DDAudioQueueBuffer *)buffer;

- (void *)malloc:(size_t)size;
- (void)free:(void *)bytes;
@end

@implementation DDAudioQueue

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _delegate = delegate;
    _mallocData = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc
{
    [self removeFromRunLoop];
    [self reset];
    [_mallocData release];
    [super dealloc];
}

static void MyPerformCallback(void * info)
{
    DDAudioQueue * self = info;
    [self callDelegateForAvailableBuffers];
}

- (void)callDelegateForAvailableBuffers;
{
    DDAudioQueueBuffer * buffer = NULL;
    DDAtomicListRef availableList = DDAtomicListSteal(&_availableList);
    DDAtomicListReverse(&availableList, NODE_OFFSET);
    do {
        buffer = DDAtomicListPop(&availableList, NODE_OFFSET);
        [self callDelegateForBuffer:buffer];
    } while (buffer != NULL);
}

- (void)callDelegateForBuffer:(DDAudioQueueBuffer *)buffer;
{
    if (buffer == NULL) {
        return;
    }
    
    buffer->length = 0;
    if (buffer == DDAudioQueueFenceBuffer) {
        if ([_delegate respondsToSelector:@selector(audioQueueDidReceiveFence:)]) {
            [_delegate audioQueueDidReceiveFence:self];
        }
    } else {
        [self->_delegate audioQueue:self bufferIsAvailable:buffer];
    }
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

- (void)popAllFromList:(DDAtomicListRef *)list
{
	while (DDAtomicListPop(list, NODE_OFFSET)) {
    }
}

- (void)reset;
{
    [self popAllFromList:&_bufferList];
    [self popAllFromList:&_renderList];
    [self popAllFromList:&_availableList];
}

- (DDAudioQueueBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;
{
    DDAudioQueueListNode * node = [self malloc:sizeof(DDAudioQueueListNode)];
    void * bufferBytes = [self malloc:capacity];
    
    // Can only assign capacity and bytes on creation because they're const.
    // Can't create and assign dynamic memory, so cheat by creating
    // a temporary one on the stack and memcpy it to our malloc'd node.
    DDAudioQueueBuffer tempBuffer = {
        .capacity = capacity,
        .length = 0,
        .bytes = bufferBytes,
    };
    memcpy(&node->buffer, &tempBuffer, sizeof(node->buffer));
    
    DDAudioQueueBuffer * buffer = &node->buffer;
    NSAssert(node == (void *)buffer, @"Invalid node layout");
    
    return buffer;
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
    DDAtomicListInsert(&_bufferList, node, NODE_OFFSET);
    return YES;
}

- (void)enqueueFenceBuffer;
{
    DDAudioQueueFenceBuffer->length = 0;
    [self enqueueBuffer:DDAudioQueueFenceBuffer];
}

- (void *)malloc:(size_t)size;
{
    NSMutableData * data = [NSMutableData dataWithLength:size];
    void * bytes = [data mutableBytes];
    NSValue * bytesValue = [NSValue valueWithPointer:bytes];
    [_mallocData setObject:data forKey:bytesValue];
    return bytes;
}

- (void)free:(void *)bytes;
{
    NSValue * bytesValue = [NSValue valueWithPointer:bytes];
    [_mallocData removeObjectForKey:bytesValue];
}

#pragma mark -
#pragma mark C API

DDAudioQueueBuffer * DDAudioQueueDequeueBuffer(DDAudioQueue * queue)
{
    DDAudioQueueBuffer * buffer = DDAtomicListPop(&queue->_renderList, NODE_OFFSET);
    if (buffer == nil) {
        queue->_renderList = DDAtomicListSteal(&queue->_bufferList);
        DDAtomicListReverse(&queue->_renderList, NODE_OFFSET);
        buffer = DDAtomicListPop(&queue->_renderList, NODE_OFFSET);
    }
    return buffer;
}

void DDAudioQueueMakeBufferAvailable(DDAudioQueue * queue, DDAudioQueueBuffer * buffer)
{
    DDAtomicListInsert(&queue->_availableList, buffer, NODE_OFFSET);
    CFRunLoopSourceSignal(queue->_runLoopSource);
    CFRunLoopWakeUp(queue->_runLoop);
}

@end
