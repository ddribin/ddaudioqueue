//

#import <Foundation/Foundation.h>
#import "DDAtomicList.h"
#import "DDAudioQueueBuffer.h"

@protocol DDAudioQueueDelegate;

@interface DDAudioQueue : NSObject
{
    id<DDAudioQueueDelegate> _delegate;
    BOOL _isStarted;
    NSMutableDictionary * _mallocData;
    DDAtomicListRef _bufferList;
    DDAtomicListRef _renderList;
    DDAtomicListRef _availableList;
    CFRunLoopRef _runLoop;
    CFRunLoopSourceRef _runLoopSource;
}

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (void)removeFromRunLoop;

- (void)reset;

- (DDAudioQueueBuffer *)allocateBufferWithCapacity:(NSUInteger)capacity error:(NSError **)error;

- (void)deallocateBuffer:(DDAudioQueueBuffer *)buffer;

- (BOOL)enqueueBuffer:(DDAudioQueueBuffer *)buffer;

@end

DDAudioQueueBuffer * DDAudioQueueDequeueBuffer(DDAudioQueue * queue);

void DDAudioQueueMakeBufferAvailable(DDAudioQueue * queue, DDAudioQueueBuffer * buffer);
