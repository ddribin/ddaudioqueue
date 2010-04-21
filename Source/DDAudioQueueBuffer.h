//

#import <Foundation/Foundation.h>

typedef struct DDAudioQueueBuffer
{
    const NSUInteger capacity;
    NSUInteger length;
    void * const bytes;
} DDAudioQueueBuffer;

#if 0
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
#endif

const void * DDAudioQueueBufferGetBytes(DDAudioQueueBuffer * buffer);
NSUInteger DDAudioQueueBufferGetLength(DDAudioQueueBuffer * buffer);
