/*
 *  DDAtomicList.c
 *  DDAudioQueue
 *
 *  Created by Dave Dribin on 4/20/10.
 *  Copyright 2010 Bit Maki, Inc. All rights reserved.
 *
 */

#include "DDAtomicList.h"

#import <libkern/OSAtomic.h>


static void ** nextPointer(void * node, size_t linkOffset)
{
    uint8_t * bytes = node;
    bytes += linkOffset;
    return (void **)bytes;
}

void DDAtomicListInsert(DDAtomicListRef *listPtr, void * node, size_t linkOffset)
{
    void ** nodeNext = nextPointer(node, linkOffset);
    do {
        *nodeNext = *listPtr;
    } while( !OSAtomicCompareAndSwapPtrBarrier(*nodeNext, node, (void *)listPtr) );
}

DDAtomicListRef DDAtomicListSteal(DDAtomicListRef * listPtr)
{
    DDAtomicListRef ret;
    do {
        ret = *listPtr;
    } while( !OSAtomicCompareAndSwapPtrBarrier(ret, NULL, (void **)listPtr) );
    return ret;
}

void DDAtomicListReverse( DDAtomicListRef *listPtr, size_t linkOffset)
{
    void *cur = *listPtr;
    void *prev = NULL;
    void *next = NULL;
    
    if (cur == NULL)
        return;
    
    do {
        void ** curNext = nextPointer(cur, linkOffset);
        next = *curNext;
        *curNext = prev;
        
        if (next) {
            prev = cur;
            cur = next;
        }
    } while (next);
    
    *listPtr = cur;
}

void *DDAtomicListPop( DDAtomicListRef *listPtr, size_t linkOffset)
{
    void * node = *listPtr;
    if (node == NULL)
        return NULL;
    void ** nodeNext = nextPointer(node, linkOffset);
    *listPtr = *nodeNext;
    *nodeNext = NULL;
    return node;
}
