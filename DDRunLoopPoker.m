/*
 * Copyright (c) 2007-2009 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "DDRunLoopPoker.h"

#define USE_MACH_PORT 0

#if USE_MACH_PORT
static const uint32_t kPokeMessage = 100;
#endif

@implementation DDRunLoopPoker

+ (id)pokerWithRunLoop:(NSRunLoop *)runLoop;
{
    id o = [[self alloc] initWithRunLoop:runLoop];
    return [o autorelease];
}

- (id)init;
{
    return [self initWithRunLoop:[NSRunLoop currentRunLoop]];
}

static void MyPerform(void * info)
{
    NSLog(@"info: %p", info);
}

- (id)initWithRunLoop:(NSRunLoop *)runLoop;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    _runLoop = [runLoop retain];
#if USE_MACH_PORT
    _pokerPort = [[NSMachPort port] retain];
    [_runLoop addPort:_pokerPort forMode:NSDefaultRunLoopMode];
    [_runLoop addPort:_pokerPort forMode:NSModalPanelRunLoopMode];
#else
    // We can set all callbacks to NULL. We're just using this as a way
    // to ensure there's at least on source on the run loop and to wake
    // up the run loop. We don't need to do anything when it fires.
    CFRunLoopSourceContext context = {
        .info = 0,
        .retain = NULL,
        .release = NULL,
        .copyDescription = NULL,
        .equal = NULL,
        .hash = NULL,
        .schedule = NULL,
        .cancel = NULL,
        .perform = MyPerform,
    };
    _pokerSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopRef cfRunLoop = [_runLoop getCFRunLoop];
    CFRunLoopAddSource(cfRunLoop, _pokerSource, (CFStringRef)NSDefaultRunLoopMode);
    CFRunLoopAddSource(cfRunLoop, _pokerSource, (CFStringRef)NSModalPanelRunLoopMode);
#endif
    
    return self;
}

- (void)dealloc
{
    [self dispose];
    
    [super dealloc];
}

- (void)finalize
{
    [self dispose];
    
    [super finalize];
}

- (void)dispose;
{
#if USE_MACH_PORT
    if (_pokerPort != nil)
    {
        [_runLoop removePort:_pokerPort forMode:NSModalPanelRunLoopMode];
        [_runLoop removePort:_pokerPort forMode:NSDefaultRunLoopMode];
    }
    [_pokerPort invalidate];
    [_pokerPort release];
    _pokerPort = nil;
#else
    CFRunLoopRef cfRunLoop = [_runLoop getCFRunLoop];
    if (_pokerSource != NULL)
    {
        CFRunLoopRemoveSource(cfRunLoop, _pokerSource, (CFStringRef)NSModalPanelRunLoopMode);
        CFRunLoopRemoveSource(cfRunLoop, _pokerSource, (CFStringRef)NSDefaultRunLoopMode);
    }
    CFRunLoopSourceInvalidate(_pokerSource);
    CFRelease(_pokerSource);
    _pokerSource = NULL;
#endif
    
    [_runLoop release];
    _runLoop = nil;
}

- (void)pokeRunLoop;
{
#if USE_MACH_PORT
    NSPortMessage * message = [[NSPortMessage alloc] initWithSendPort:_pokerPort
                                                          receivePort:nil
                                                           components:nil];
    [message autorelease];
    
    [message setMsgid:kPokeMessage];
    [message sendBeforeDate:[NSDate date]];
#elif 1
    CFRunLoopSourceSignal(_pokerSource);
    CFRunLoopRef cfRunLoop = [_runLoop getCFRunLoop];
    CFRunLoopWakeUp(cfRunLoop);
#endif
}

@end
