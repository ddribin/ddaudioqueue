//

#import <Cocoa/Cocoa.h>

@class DDAudioQueue;
@class DDAudioQueueBuffer;

@interface DDAudioQueueReader : NSObject
{
    DDAudioQueue * _queue;
    DDAudioQueueBuffer * _readBuffer;
    UInt32 _readCursor;
}

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
