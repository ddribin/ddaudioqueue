//

#import <Foundation/Foundation.h>
#import "RAAtomicList.h"

@protocol DDAudioQueueDelegate;
@class DDAudioQueueBuffer;

@interface DDAudioQueue : NSObject
{
    id<DDAudioQueueDelegate> _delegate;
    NSMutableArray * _buffers;
    BOOL _isStarted;
    RAAtomicListRef _bufferList;
    RAAtomicListRef _renderList;
    RAAtomicListRef _availableList;
    CFRunLoopRef _runLoop;
    CFRunLoopSourceRef _runLoopSource;
}

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (void)removeFromRunLoop;

- (void)reset;

- (DDAudioQueueBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;

- (BOOL)enqueueBuffer:(DDAudioQueueBuffer *)buffer;

@end

DDAudioQueueBuffer * DDAudioQueueDequeueBuffer(DDAudioQueue * queue);

void DDAudioQueueMakeBufferAvailable(DDAudioQueue * queue, DDAudioQueueBuffer * buffer);
