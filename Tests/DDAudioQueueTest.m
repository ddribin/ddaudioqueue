//

#import "DDAudioQueueTest.h"
#import "DDAudioQueue.h"
#import "DDAudioQueueBuffer.h"

#define BUFFER_COUNT (sizeof(_buffers)/sizeof(*_buffers))

static const NSUInteger CAPACITY = 10;

@implementation DDAudioQueueTest

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;
{
    STAssertEquals(_queue, queue, nil);
    [_availableBuffers addObject:buffer];
}

- (void)setUp
{
    _queue = [[DDAudioQueue alloc] initWithDelegate:self];
    [_queue scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    _buffers = [NSMutableArray array];
    _availableBuffers = [NSMutableArray array];
}

- (void)tearDown
{
    [_queue removeFromRunLoop];
    [_queue release];
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
        [_buffers addObject:buffer];
    }
}

- (DDAudioQueueBuffer *)buffer:(NSUInteger)index;
{
    return [_buffers objectAtIndex:index];
}

- (void)spinRunLoop
{
    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate:[NSDate date]];
}

#pragma mark -

- (void)testAllocatedBuffersHaveCorrectInitialValues
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    
    STAssertNotNil(buffer, nil);
    STAssertEquals(buffer.capacity, CAPACITY, nil);
    STAssertEquals(buffer.length, (NSUInteger)0, nil);
    STAssertNotNil(buffer.bytes, nil);
}

- (void)testEnqueuedBuffersAreDequeuedInOrder
{
    [self allocateBuffers:2];
    
    [_queue enqueueBuffer:[self buffer:0]];
    [_queue enqueueBuffer:[self buffer:1]];
    
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:0], nil);
    STAssertEquals(DDAudioQueueDequeueBuffer(_queue), [self buffer:1], nil);
}

- (void)testNilIsDeqeuedAfterDequeueingLastBuffer
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    [_queue enqueueBuffer:buffer];
    
    (void)DDAudioQueueDequeueBuffer(_queue);
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    
    STAssertNil(dequeuedBuffer, nil);
}

- (void)testNilIsDequeuedOnEmpty
{
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    
    STAssertNil(dequeuedBuffer, nil);
}

- (void)testDelegateIsCalledWhenBufferBecomesAvailable
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    [_queue enqueueBuffer:buffer];
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    DDAudioQueueBufferIsAvailable(_queue, dequeuedBuffer);
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)1, nil);
    STAssertEquals([_availableBuffers objectAtIndex:0], buffer, nil);
}

- (void)testAvailableBufferLengthIsZero
{
    DDAudioQueueBuffer * buffer = [self allocateBuffer];
    // Ensure the length is not zero
    buffer.length = CAPACITY;
    [_queue enqueueBuffer:buffer];
    DDAudioQueueBuffer * dequeuedBuffer = DDAudioQueueDequeueBuffer(_queue);
    DDAudioQueueBufferIsAvailable(_queue, dequeuedBuffer);
    [self spinRunLoop];
    
    buffer = [_availableBuffers objectAtIndex:0];
    STAssertEquals(buffer.length, (NSUInteger)0, nil);
}

- (void)testDequeingStealsBuffer
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
    STAssertNil(DDAudioQueueDequeueBuffer(_queue), nil);
}

@end
