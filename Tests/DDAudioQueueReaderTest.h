//

#import <SenTestingKit/SenTestingKit.h>
#import "DDAudioQueueDelegate.h"

@class DDAudioQueue;
@class DDAudioQueueReader;

@interface DDAudioQueueReaderTest : SenTestCase <DDAudioQueueDelegate>
{
    DDAudioQueue * _queue;
    DDAudioQueueReader * _reader;
    NSMutableArray * _buffers;
    NSMutableData * _readBuffer;
    NSMutableArray * _availableBuffers;
}

@end
