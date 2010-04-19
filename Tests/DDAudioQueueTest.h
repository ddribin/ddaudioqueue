//

#import <SenTestingKit/SenTestingKit.h>
#import "DDAudioQueueDelegate.h"

@class DDAudioQueue;
@class DDAudioQueueBuffer;

@interface DDAudioQueueTest : SenTestCase <DDAudioQueueDelegate>
{
    DDAudioQueue * _queue;
    NSMutableArray * _buffers;
    NSMutableArray * _availableBuffers;
}

@end
