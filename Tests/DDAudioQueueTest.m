//

#import "DDAudioQueueTest.h"
#import "DDAudioQueue.h"
#import "DDAudioQueueBuffer.h"

#define BUFFER_COUNT (sizeof(_buffers)/sizeof(*_buffers))

#define STAssertNull(_A_, _M_) STAssertNil((id)_A_, _M_)

static const NSUInteger CAPACITY = 10;

@implementation DDAudioQueueTest

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;
{
    STAssertEquals(_queue, queue, nil);
    [_availableBuffers addObject:[NSValue valueWithPointer:buffer]];
}

- (void)audioQueueDidReceiveFence:(DDAudioQueue *)queue;
{
    _fenceCount++;
}

- (DDAudioQueueBuffer *)availableBuffer:(NSUInteger)index
{
    NSValue * value = [_availableBuffers objectAtIndex:index];
    return [value pointerValue];
}

- (DDAudioQueueBuffer *)allocateBuffer
{
    DDAudioQueueBuffer * buffer = [_queue allocateBufferWithCapacity:CAPACITY error:NULL];
    return buffer;
}

- (void)allocateBuffers:(int)count
{
    for (int i = 0; i < count; i++) {
        DDAudioQueueBuffer * buffer = [self allocateBuffer];
        [_buffers addObject:[NSValue valueWithPointer:buffer]];
    }
}

- (DDAudioQueueBuffer *)buffer:(NSUInteger)index;
{
    NSValue * bufferValue = [_buffers objectAtIndex:index];
    return [bufferValue pointerValue];
}

- (void)spinRunLoop
{
    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate:[NSDate date]];
}

- (void)dequeueAndMakeAvailable
{
    DDAudioQueueBuffer * buffer = DDAudioQueueDequeueBuffer(_queue);
    DDAudioQueueMakeBufferAvailable(_queue, buffer);
}

#pragma mark -

- (void)setUp
{
    _queue = [[DDAudioQueue alloc] initWithDelegate:self];
    [_queue scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    _buffers = [NSMutableArray array];
    _availableBuffers = [NSMutableArray array];
    _fenceCount = 0;
}

- (void)tearDown
{
    [_queue removeFromRunLoop];
    [_queue release];
}

#pragma mark -
#pragma mark Tests

- (void)testAllocatesBuffersWithCorrectInitialValues
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    
    STAssertFalse(buffer == NULL, nil);
    STAssertEquals(buffer->capacity, CAPACITY, nil);
    STAssertEquals(buffer->length, (NSUInteger)0, nil);
    STAssertNotNil(buffer->bytes, nil);
}

- (void)testCanDeallocateBuffer
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    [_queue deallocateBuffer:buffer];
}

- (void)testDequeuesBuffersInOrderTheyAreEnqeueued
{
    [self allocateBuffers:2];
    
    [_queue enqueueBuffer:[self buffer:0]];
    [_queue enqueueBuffer:[self buffer:1]];
    
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:0], nil);
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:1], nil);
}

- (void)testDequeuesNilAfterDequeueingLastBuffer
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    [_queue enqueueBuffer:buffer];
    
    (void)DDAudioQueueDequeueBuffer(_queue);
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    
    STAssertNull(dequeuedBuffer, nil);
}

- (void)testDequeuessNilOnEmpty
{
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    
    STAssertNull(dequeuedBuffer, nil);
}

- (void)testCallsDelegateWhenBufferBecomesAvailable
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    [_queue enqueueBuffer:buffer];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)1, nil);
    STAssertEquals([self availableBuffer:0], buffer, nil);
}

- (void)testResetsAvailableBufferLengthToZero
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    // Ensure the length is not zero
    buffer->length = CAPACITY;
    [_queue enqueueBuffer:buffer];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    buffer = [self availableBuffer:0];
    STAssertEquals(buffer->length, (NSUInteger)0, nil);
}

- (void)testSendsMultipleAvailableToDelegateInReverseOrder
{
    [self allocateBuffers:2];
    [_queue enqueueBuffer:[self buffer:0]];
    [_queue enqueueBuffer:[self buffer:1]];
    [self dequeueAndMakeAvailable];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)2, nil);
    STAssertEquals([self availableBuffer:0], [self buffer:1], nil);
    STAssertEquals([self availableBuffer:1], [self buffer:0], nil);
}

- (void)testDequeuePopsFromInternalListsInProperOrder
{
    [self allocateBuffers:5];
    [_queue enqueueBuffer:[self buffer:0]];
    [_queue enqueueBuffer:[self buffer:1]];
    [_queue enqueueBuffer:[self buffer:2]];
    
    // Calling a dequeue steals the buffer list to the render list
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    STAssertEquals(dequeuedBuffer, [self buffer:0], nil);
    
    [_queue enqueueBuffer:[self buffer:3]];
    [_queue enqueueBuffer:[self buffer:4]];
     
    // At this point there should be 2 buffers on the render list and 2 on the buffer list
    // Make sure they come out in the right order
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:1], nil);
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:2], nil);
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:3], nil);
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:4], nil);
    STAssertNull(DDAudioQueueDequeueBuffer(_queue), nil);
}

#pragma mark -

- (void)testDoesNotCallFenceDelegateIfNoFenceIsEnqueued
{
    [self allocateBuffers:1];
    [_queue enqueueBuffer:[self buffer:0]];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    STAssertEquals(_fenceCount, 0, nil);
}

- (void)testCallsFenceDelegateAfterEnqueuingAndProcessingFence
{
    [_queue enqueueFenceBuffer];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    STAssertEquals(_fenceCount, 1, nil);
}

- (void)testCallsFenceDelegateAfterDequeingAllBuffers
{
    [self allocateBuffers:1];
    [_queue enqueueBuffer:[self buffer:0]];
    [self dequeueAndMakeAvailable];

    [_queue enqueueFenceBuffer];
    [self dequeueAndMakeAvailable];
    
    [self spinRunLoop];
    
    STAssertEquals(_fenceCount, 1, nil);
}

@end
