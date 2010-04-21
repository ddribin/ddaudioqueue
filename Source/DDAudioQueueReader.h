//

#import <Cocoa/Cocoa.h>
#import "DDAudioQueueBuffer.h"

@class DDAudioQueue;

@interface DDAudioQueueReader : NSObject
{
    DDAudioQueue * _queue;
    DDAudioQueueBuffer * _readBuffer;
    UInt32 _readCursor;
    UInt32 _underflowCount;
}

@property (nonatomic, readonly) UInt32 underflowCount;

- (id)initWithAudioQueue:(DDAudioQueue *)queue;

- (void)reset;

@end

/**
 * Reads bytesToRead bytes into the buffer, dequeing as necessary.  If there
 * is not enough data available, it only copies in the number of bytes
 * read.
 *
 * @return The actual number of bytes dequeued and copied into the buffer
 */
UInt32 DDAudioQueueReaderRead(DDAudioQueueReader * reader, void * buffer, UInt32 bytesToRead);
