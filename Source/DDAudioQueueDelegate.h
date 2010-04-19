//

#import <Foundation/Foundation.h>

@class DDAudioQueue;
@class DDAudioQueueBuffer;

@protocol DDAudioQueueDelegate <NSObject>

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;

@end
