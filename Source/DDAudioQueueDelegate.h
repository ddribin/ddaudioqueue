//

#import <Foundation/Foundation.h>
#import "DDAudioQueueBuffer.h"

@class DDAudioQueue;


@protocol DDAudioQueueDelegate <NSObject>

- (void)audioQueue:(DDAudioQueue *)queue bufferIsAvailable:(DDAudioQueueBuffer *)buffer;

@optional

- (void)audioQueueDidReceiveFence:(DDAudioQueue *)queue;

@end
