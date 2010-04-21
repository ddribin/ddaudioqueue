//

#import "DDAudioQueueReaderTest.h"
#import "DDAudioQueueReader.h"
#import "DDAudioQueue.h"
#import "DDAudioQueueBuffer.h"


static const NSUInteger QUEUE_BUFFER_SIZE = 10;
static const uint8_t SCRIBBLE = 0x55;
static const NSUInteger READ_BUFFER_SIZE = 50;

@implementation DDAudioQueueReaderTest

- (DDAudioQueueBuffer *)buffer:(NSUInteger)index
{
    NSValue * value = [_buffers objectAtIndex:index];
    return [value pointerValue];
}

- (void)assertReadBufferFrom:(NSUInteger)from to:(NSUInteger)to isSetTo:(uint8_t)value
{
    STAssertTrue(to < [_readBuffer length], @"%u should be less than %u", to, [_readBuffer length]);
    uint8_t * byteBuffer = [_readBuffer mutableBytes];
    for (NSUInteger i = from; i <= to; i++) {
        STAssertEquals(byteBuffer[i], value, @"Byte %u should be 0x%02X but was 0x%02X",
                       i, value, byteBuffer[i]);
    }
}

- (void)enqueueBuffer:(NSUInteger)bufferIndex withValue:(uint8_t)value length:(NSUInteger)length
{
    DDAudioQueueBuffer * buffer = [self buffer:bufferIndex];
    STAssertFalse(buffer == NULL, nil);
    STAssertTrue(length <= buffer->capacity, nil);
    memset(buffer->bytes, value, length);
    buffer->length = length;
    [_queue enqueueBuffer:buffer];
}

- (UInt32)readBytes:(UInt32)bytesToRead toOffset:(NSUInteger)offset
{
    STAssertTrue(bytesToRead + offset <= [_readBuffer length], nil);
    uint8_t * bytes = [_readBuffer mutableBytes];
    bytes += offset;
    UInt32 bytesRead = DDAudioQueueReaderRead(_reader, bytes, bytesToRead);
    return bytesRead;
}

- (UInt32)readBytes:(UInt32)bytesToRead
{
    return [self readBytes:bytesToRead toOffset:0];
}

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;
{
    STAssertEquals(_queue, queue, nil);
    [_availableBuffers addObject:[NSValue valueWithPointer:buffer]];
}

- (DDAudioQueueBuffer *)availableBuffer:(NSUInteger)index
{
    NSValue * value = [_availableBuffers objectAtIndex:index];
    return [value pointerValue];
}

- (void)spinRunLoop
{
    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
    [runLoop runUntilDate:[NSDate date]];
}

#pragma mark -

- (void)setUpBuffers
{
    for (int i = 0; i < 3; i++) {
        DDAudioQueueBuffer * buffer = [_queue allocateBufferWithCapacity:QUEUE_BUFFER_SIZE error:NULL];
        STAssertFalse(buffer == NULL, nil);
        [_buffers addObject:[NSValue valueWithPointer:buffer]];
    }
}

- (void)setUp
{
    _queue = [[[DDAudioQueue alloc] initWithDelegate:self] autorelease];
    _buffers = [NSMutableArray array];
    [self setUpBuffers];
    [_queue scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    _reader = [[[DDAudioQueueReader alloc] initWithAudioQueue:_queue] autorelease];
    _readBuffer = [NSMutableData dataWithLength:READ_BUFFER_SIZE];
    memset([_readBuffer mutableBytes], SCRIBBLE, READ_BUFFER_SIZE);
    _availableBuffers = [NSMutableArray array];
}

- (void)tearDown
{
    [_queue removeFromRunLoop];
}

#pragma mark -
#pragma mark Tests

- (void)testReturnsZeroReadingFromEmptyQueue
{
    UInt32 bytesRead = [self readBytes:READ_BUFFER_SIZE];

    STAssertEquals(bytesRead, (UInt32)0, nil);
}

- (void)testDoesNotCopyAnyDataReadingFromEmptyQueue
{
    [self readBytes:READ_BUFFER_SIZE];

    [self assertReadBufferFrom:0 to:READ_BUFFER_SIZE-1 isSetTo:SCRIBBLE];
}

- (void)testReadsProperDataWhenReadingSizeOfEnequeuedBuffer
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    
    UInt32 bytesRead = [self readBytes:10];
    
    STAssertEquals(bytesRead, (UInt32)10, nil);
    [self assertReadBufferFrom:0 to:9 isSetTo:0x01];
    [self assertReadBufferFrom:10 to:READ_BUFFER_SIZE-1 isSetTo:SCRIBBLE];
}

- (void)testReadsProperDataWhenReadDoesNotSpanWholeBuffer
{
    DDAudioQueueBuffer * buffer = [self buffer:0];
    uint8_t pattern[] = {0x01,  0x01, 0x02, 0x02};
    memcpy(buffer->bytes, pattern, 4);
    buffer->length = 4;
    [_queue enqueueBuffer:buffer];
    
    UInt32 bytesRead = 0;
    bytesRead += [self readBytes:2 toOffset:0];
    bytesRead += [self readBytes:2 toOffset:2];
    
    STAssertEquals(bytesRead, (UInt32)4, nil);
    [self assertReadBufferFrom:0 to:1 isSetTo:0x01];
    [self assertReadBufferFrom:2 to:3 isSetTo:0x02];
    [self assertReadBufferFrom:4 to:READ_BUFFER_SIZE-1 isSetTo:SCRIBBLE];
}

- (void)testReadsNoBytesAfterDequeingOnlyBuffer
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    
    [self readBytes:10];
    UInt32 bytesRead = [self readBytes:10 toOffset:11];
    
    STAssertEquals(bytesRead, (UInt32)0, nil);
    [self assertReadBufferFrom:0 to:9 isSetTo:0x01];
    [self assertReadBufferFrom:10 to:READ_BUFFER_SIZE-1 isSetTo:SCRIBBLE];
}

- (void)testReadingSpansMultipleBuffers
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [self enqueueBuffer:1 withValue:0x02 length:5];
    
    UInt32 bytesRead = [self readBytes:READ_BUFFER_SIZE];
    
    STAssertEquals(bytesRead, (UInt32)15, nil);
    [self assertReadBufferFrom:0 to:9 isSetTo:0x01];
    [self assertReadBufferFrom:10 to:14 isSetTo:0x02];
    [self assertReadBufferFrom:15 to:READ_BUFFER_SIZE-1 isSetTo:SCRIBBLE];
}

- (void)testDoesNotMakeReadingPartialBufferAvailable
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    
    [self readBytes:5];
    [self spinRunLoop];

    STAssertEquals([_availableBuffers count], (NSUInteger)0, nil);
}

- (void)testMakesBufferAvailableAfterReadingFullBuffer
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    
    [self readBytes:10];
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)1, nil);
    STAssertEquals([self availableBuffer:0], [self buffer:0], nil);
}

- (void)testMakesAllBuffersAavailableAfterMultiBufferRead
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [self enqueueBuffer:1 withValue:0x02 length:10];
    [self enqueueBuffer:2 withValue:0x03 length:10];
    
    [self readBytes:30];
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)3, nil);
    // They become available in reverse order
    STAssertEquals([self availableBuffer:0], [self buffer:2], nil);
    STAssertEquals([self availableBuffer:1], [self buffer:1], nil);
    STAssertEquals([self availableBuffer:2], [self buffer:0], nil);
}

- (void)testReadingMoreBytesThanEqueued
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [self enqueueBuffer:1 withValue:0x02 length:10];
    [self enqueueBuffer:2 withValue:0x03 length:10];
    
    [self readBytes:40];
    [self spinRunLoop];
    
    STAssertEquals([_availableBuffers count], (NSUInteger)3, nil);
    // They become available in reverse order
    STAssertEquals([self availableBuffer:0], [self buffer:2], nil);
    STAssertEquals([self availableBuffer:1], [self buffer:1], nil);
    STAssertEquals([self availableBuffer:2], [self buffer:0], nil);
}

- (void)testStopsReadingAtFence
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [self enqueueBuffer:1 withValue:0x02 length:10];
    [_queue enqueueFenceBuffer];
    [self enqueueBuffer:2 withValue:0x03 length:10];
    
    UInt32 bytesRead = [self readBytes:READ_BUFFER_SIZE];
    [self spinRunLoop];
    
    STAssertEquals(bytesRead, (UInt32)20, nil);
    STAssertEquals([_availableBuffers count], (NSUInteger)2, nil);
    // They become available in reverse order
    STAssertEquals([self availableBuffer:0], [self buffer:1], nil);
    STAssertEquals([self availableBuffer:1], [self buffer:0], nil);
}

- (void)testContinuesReadingAtFence
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [self enqueueBuffer:1 withValue:0x02 length:10];
    [_queue enqueueFenceBuffer];
    [self enqueueBuffer:2 withValue:0x03 length:10];
    [self readBytes:READ_BUFFER_SIZE];
    [self spinRunLoop];
    [_availableBuffers removeAllObjects];
    
    UInt32 bytesRead = [self readBytes:READ_BUFFER_SIZE];
    [self spinRunLoop];
    
    STAssertEquals(bytesRead, (UInt32)10, nil);
    STAssertEquals([_availableBuffers count], (NSUInteger)1, nil);
    STAssertEquals([self availableBuffer:0], [self buffer:2], nil);
}

- (void)testTriggersUnderflowReadingMoreBytesThanEnqueued
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    
    [self readBytes:READ_BUFFER_SIZE];
    
    STAssertEquals([_reader underflowCount], (UInt32)1, nil);
}

- (void)testTriggersUnderflowOnFence
{
    [self enqueueBuffer:0 withValue:0x01 length:10];
    [_queue enqueueFenceBuffer];
    [self enqueueBuffer:1 withValue:0x02 length:10];
    
    [self readBytes:READ_BUFFER_SIZE];
    [self spinRunLoop];
    
    STAssertEquals([_reader underflowCount], (UInt32)1, nil);
}


@end
