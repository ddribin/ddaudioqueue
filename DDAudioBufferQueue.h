//
//  DDAudioBufferQueue.h
//  RunLoopSource
//
//  Created by Dave Dribin on 4/17/10.
//  Copyright 2010 Bit Maki, Inc.. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RAAtomicList.h"

@class DDAudioBufferQueue;
@class DDAudioBuffer;

@protocol DDAudioQueueDelegate <NSObject>

- (void)audioQueue:(DDAudioBufferQueue *)queue bufferIsAvailable:(DDAudioBuffer *)buffer;

@end

@interface DDAudioBuffer : NSObject
{
    @private
    NSMutableData * _data;
    NSUInteger _capacity;
    void * _bytes;
    NSUInteger _length;
}

@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) void * bytes;
@property (nonatomic, readwrite) NSUInteger length;

- (id)initWithCapacity:(NSUInteger)capacity;

@end

const void * DDAudioBufferBytes(DDAudioBuffer * buffer);
NSUInteger DDAudioBufferLength(DDAudioBuffer * buffer);


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
