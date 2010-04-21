//

#import <SenTestingKit/SenTestingKit.h>
#import "DDAudioQueueDelegate.h"
#import "DDAudioQueueBuffer.h"

@class DDAudioQueue;

@interface DDAudioQueueTest : SenTestCase <DDAudioQueueDelegate>
{
    DDAudioQueue * _queue;
    NSMutableArray * _buffers;
    NSMutableArray * _availableBuffers;
    BOOL _addFenceToAvailableBuffers;
    int _fenceCount;
}

@end
