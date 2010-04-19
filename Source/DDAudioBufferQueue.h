//

#import <Foundation/Foundation.h>
#import "RAAtomicList.h"

@class DDAudioBufferQueue;
@class DDAudioBuffer;

@protocol DDAudioQueueDelegate <NSObject>

- (void)audioQueue:(DDAudioBufferQueue *)queue bufferIsAvailable:(DDAudioBuffer *)buffer;

@end


@interface DDAudioBufferQueue : NSObject
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

- (DDAudioBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;

- (BOOL)enqueueBuffer:(DDAudioBuffer *)buffer;

@end

DDAudioBuffer * DDAudioQueueDequeueBuffer(DDAudioBufferQueue * queue);

void DDAudioQueueBufferIsAvailable(DDAudioBufferQueue * queue, DDAudioBuffer * buffer);
