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

typedef struct DDAudioReadBuffer
{
    const NSUInteger audioDataCapacity;
    const void * const audioData;
    void * const userData;
} DDAudioReadBuffer;

@interface DDAudioBuffer : NSObject
{
    @private
    NSMutableData * _data;
    NSData * _identifier;
    DDAudioReadBuffer _readBuffer;

    // Used for read buffer
    NSUInteger _audioDataBytesCapacity;
    void * _audioData;
    NSUInteger _audioDataByteSize;
    void * _userData;
}

- (id)initWithCapacity:(NSUInteger)capacity;
- (NSData *)identifier;
- (NSMutableData *)data;

void DDAudioBufferGetReadBuffer(DDAudioBuffer * buffer, DDAudioReadBuffer * readBuffer);

@end


@interface DDAudioBufferQueue : NSObject
{
    id<DDAudioQueueDelegate> _delegate;
    NSMutableDictionary * _buffers;
    BOOL _isStarted;
    RAAtomicListRef _bufferList;
    RAAtomicListRef _renderList;
    CFMessagePortRef _messagePort;
    CFRunLoopSourceRef _messagePortSource;
}

- (id)initWithDelegate:(id<DDAudioQueueDelegate>)delegate;

- (BOOL)start:(NSError **)error;

- (void)stop;

- (DDAudioBuffer *)allocateBufferWithSize:(NSUInteger)size error:(NSError **)error;

- (BOOL)enqueueBuffer:(DDAudioBuffer *)buffer;

@end

DDAudioBuffer * DDAudioQueueDequeueBuffer(DDAudioBufferQueue * queue);

void DDAudioQueueBufferIsAvailable(DDAudioBufferQueue * queue, DDAudioBuffer * buffer);
