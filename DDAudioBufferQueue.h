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

const void * DDAudioBufferBytes(DDAudioBuffer * buffer);
NSUInteger DDAudioBufferLength(DDAudioBuffer * buffer);

@end


@interface DDAudioBufferQueue : NSObject
{
    id<DDAudioQueueDelegate> _delegate;
    NSMutableArray * _buffers;
    NSMutableDictionary * _buffersByIdentifier;
    BOOL _isStarted;
    RAAtomicListRef _bufferList;
    RAAtomicListRef _renderList;
    RAAtomicListRef _availableList;
    CFRunLoopSourceRef _runLoopSource;
    CFRunLoopRef _runLoop;
}

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;

- (BOOL)start:(NSError **)error;

- (void)stop;

- (void)reset;

- (DDAudioBuffer *)allocateBufferWithSize:(NSUInteger)size error:(NSError **)error;

- (BOOL)enqueueBuffer:(DDAudioBuffer *)buffer;

@end

DDAudioBuffer * DDAudioQueueDequeueBuffer(DDAudioBufferQueue * queue);

void DDAudioQueueBufferIsAvailable(DDAudioBufferQueue * queue, DDAudioBuffer * buffer);
