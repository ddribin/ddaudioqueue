//

#import "DDAudioQueueBuffer.h"


@implementation DDAudioQueueBuffer

- (id)initWithCapacity:(NSUInteger)capacity;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _data = [[NSMutableData alloc] initWithLength:capacity];
    _capacity = capacity;
    _bytes = [_data mutableBytes];
    _length = 0;
    
    return self;
}

- (void) dealloc
{
    [_data release];
    [super dealloc];
}

- (NSUInteger)capacity;
{
    return _capacity;
}

- (void *)bytes;
{
    return _bytes;
}

- (NSUInteger)length;
{
    return _length;
}

- (void)setLength:(NSUInteger)length;
{
    _length = length;
}

const void * DDAudioQueueBufferGetBytes(DDAudioQueueBuffer * buffer)
{
    return buffer->_bytes;
}

NSUInteger DDAudioQueueBufferGetLength(DDAudioQueueBuffer * buffer)
{
    return buffer->_length;
}

@end
