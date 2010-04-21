//

#import "DDAudioQueueReader.h"
#import "DDAudioQueue.h"
#import "DDAudioQueueBuffer.h"


@implementation DDAudioQueueReader

- (id)initWithAudioQueue:(DDAudioQueue *)queue;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _queue = [queue retain];
    
    return self;
}

- (void)dealloc
{
    [_queue release];
    [super dealloc];
}

- (void)reset;
{
    _readBuffer = nil;
    _readCursor = 0;
}

/**
 * Reads only from a single reader->_readBuffer.  If reading completes this,
 * buffer, it gets made available.
 */
static UInt32 primitiveRead(DDAudioQueueReader * reader, void * buffer, UInt32 bytesToRead)
{
    if (reader->_readBuffer == nil) {
        reader->_readBuffer = DDAudioQueueDequeueBuffer(reader->_queue);
        reader->_readCursor = 0;
    }
    
    if (reader->_readBuffer == nil) {
        return 0;
    }
    
    NSUInteger bufferLength = DDAudioQueueBufferGetLength(reader->_readBuffer);
    NSUInteger bytesRemainingInReadBuffer = bufferLength - reader->_readCursor;
    UInt32 bytesToCopy = MIN(bytesToRead, bytesRemainingInReadBuffer);

    const uint8_t * readBufferBytes = DDAudioQueueBufferGetBytes(reader->_readBuffer);
    readBufferBytes += reader->_readCursor;
    
    memcpy(buffer, readBufferBytes, bytesToCopy);
    reader->_readCursor += bytesToCopy;
    
    if (bytesToCopy == bytesRemainingInReadBuffer) {
        DDAudioQueueMakeBufferAvailable(reader->_queue, reader->_readBuffer);
        reader->_readBuffer = nil;
    }
    
    return bytesToCopy;
}

UInt32 DDAudioQueueReaderRead(DDAudioQueueReader * reader, void * buffer, UInt32 bytesToRead)
{
    UInt32 bytesRead = 0;
    uint8_t * byteBuffer = buffer;
    
    while (bytesRead < bytesToRead) {
        UInt32 bytesToReadThisIteration = bytesToRead - bytesRead;
        UInt32 bytesReadThisIteration =
            primitiveRead(reader, byteBuffer, bytesToReadThisIteration);
        
        if (bytesReadThisIteration == 0) {
            break;
        }
        bytesRead += bytesReadThisIteration;
        byteBuffer += bytesReadThisIteration;
    }
    
    if (bytesRead < bytesToRead) {
        printf("underflow: %u %u\n", (unsigned)bytesToRead, (unsigned)bytesRead);
    }
    
    return bytesRead;
}

@end
