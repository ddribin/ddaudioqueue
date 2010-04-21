//

#import <Foundation/Foundation.h>
#import "RAAtomicList.h"
#import "DDAtomicList.h"
#import "DDAudioQueueBuffer.h"

@protocol DDAudioQueueDelegate;

@interface DDAudioQueue : NSObject
{
    id<DDAudioQueueDelegate> _delegate;
    BOOL _isStarted;
    NSMutableArray * _buffers;
    RAAtomicListRef _bufferList;
    RAAtomicListRef _renderList;
    RAAtomicListRef _availableList;
    NSMutableArray * _nodes;
    NSMutableDictionary * _nodeDataByByteAddress;
    NSMutableDictionary * _mallocData;
    NSMutableArray * _buffers2;
    DDAtomicListRef _bufferList2;
    DDAtomicListRef _renderList2;
    DDAtomicListRef _availableList2;
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
