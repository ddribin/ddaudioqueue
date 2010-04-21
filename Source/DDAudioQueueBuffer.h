//

#import <Foundation/Foundation.h>

typedef struct DDAudioQueueBuffer
{
    const NSUInteger capacity;
    NSUInteger length;
    void * const bytes;
} DDAudioQueueBuffer;
