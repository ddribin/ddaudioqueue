//

#import <Foundation/Foundation.h>


@interface DDAudioQueueBuffer : NSObject
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

const void * DDAudioBufferBytes(DDAudioQueueBuffer * buffer);
NSUInteger DDAudioBufferLength(DDAudioQueueBuffer * buffer);
