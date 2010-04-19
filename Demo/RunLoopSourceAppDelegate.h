//
//  RunLoopSourceAppDelegate.h
//  RunLoopSource
//
//  Created by Dave Dribin on 4/17/10.
//  Copyright 2010 Bit Maki, Inc.. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDRunLoopPoker.h"
#import "DDAudioBufferQueue.h"

@class DDAudioBufferQueue;
@class DDAudioBuffer;

@interface RunLoopSourceAppDelegate : NSObject <NSApplicationDelegate, DDAudioQueueDelegate> {
    NSWindow *window;
    DDRunLoopPoker * _poker;
    DDAudioBufferQueue * _audioQueue;
    DDAudioBuffer * _activeBuffer;
    int _counter;
}

@property (assign) IBOutlet NSWindow *window;

@end
