//
//  DDAtomicListTest.m
//  DDAudioQueue
//
//  Created by Dave Dribin on 4/20/10.
//  Copyright 2010 Bit Maki, Inc. All rights reserved.
//

#import "DDAtomicListTest.h"
#include "DDAtomicList.h"

/*
 * This just tests the semantics of DDAtomicList, not the thread safety.
 */

typedef struct
{
    int data;
    void * next;
} DDTestNode;

#define NEXT_OFFSET offsetof(DDTestNode, next)

// Something non-NULL and not a valid node pointer
static void * SCRIBBLE = &SCRIBBLE;

@implementation DDAtomicListTest

- (void)testScribbleIsNotNull
{
    // Just to be sure...
    STAssertTrue(SCRIBBLE != NULL, nil);
}

- (void)testUpdatesPointersOnSingleInsert
{
    DDTestNode node = {
        .data = 1,
        .next = SCRIBBLE,
    };
    DDAtomicListRef list = NULL;
    
    DDAtomicListInsert(&list, &node, NEXT_OFFSET);
    
    STAssertEquals(list, (void*)&node, nil);
    STAssertEquals(node.next, NULL, nil);
}

- (void)testUpdatesPointersOnMultipleInserts
{
    DDTestNode node1 = {
        .data = 1,
        .next = SCRIBBLE,
    };
    DDTestNode node2 = {
        .data = 2,
        .next = SCRIBBLE,
    };
    DDTestNode node3 = {
        .data = 3,
        .next = SCRIBBLE,
    };
    DDAtomicListRef list = NULL;
    
    DDAtomicListInsert(&list, &node1, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node2, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node3, NEXT_OFFSET);
    
    STAssertEquals(list, (void*)&node3, nil);
    STAssertEquals(node3.next, (void *)&node2, nil);
    STAssertEquals(node2.next, (void *)&node1, nil);
    STAssertEquals(node1.next, NULL, nil);
}

- (void)testPopsNullOnEmptyList
{
    DDAtomicListRef list = NULL;
    
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), NULL, nil);
}

- (void)testPopsNodesInLIFOOrder
{
    DDTestNode node1 = { .data = 1 };
    DDTestNode node2 = { .data = 2 };
    DDTestNode node3 = { .data = 3 };
    DDAtomicListRef list = NULL;
    
    DDAtomicListInsert(&list, &node1, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node2, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node3, NEXT_OFFSET);
    
    // LIFO order: popped in reverse order they were inserted
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node3, nil);
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node2, nil);
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node1, nil);
    STAssertEquals(list, NULL, nil);
}

- (void)testSetsNextOfPoppedNodeToNull
{
    DDTestNode node1 = { 
        .data = 1,
        .next = SCRIBBLE,
    };
    DDTestNode node2 = { 
        .data = 2,
        .next = SCRIBBLE,
    };
    DDAtomicListRef list = NULL;
    
    // Need to insert two nodes. A node in a single node list already points to NULL.
    DDAtomicListInsert(&list, &node1, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node2, NEXT_OFFSET);
    DDTestNode * poppedNode = DDAtomicListPop(&list, NEXT_OFFSET);
    
    STAssertEquals(poppedNode->next, NULL, nil);
}

- (void)testStealingListSwapsListPointers
{
    DDTestNode node = { .data = 1 };
    DDAtomicListRef list1 = NULL;
    DDAtomicListRef list2 = NULL;
    DDAtomicListInsert(&list1, &node, NEXT_OFFSET);
    DDAtomicListRef originalList1 = list1;
    
    list2 = DDAtomicListSteal(&list1);
    
    STAssertEquals(list2, originalList1, nil);
    STAssertEquals(list1, NULL, nil);
}

- (void)testReversingEmptyListIsNOOP
{
    DDAtomicListRef list = NULL;
    
    DDAtomicListReverse(&list, NEXT_OFFSET);
    
    STAssertEquals(list, NULL, nil);
}

- (void)testReversingListsPopsNodesInFIFOOrder
{
    DDTestNode node1 = { .data = 1 };
    DDTestNode node2 = { .data = 2 };
    DDTestNode node3 = { .data = 3 };
    DDAtomicListRef list = NULL;
    
    DDAtomicListInsert(&list, &node1, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node2, NEXT_OFFSET);
    DDAtomicListInsert(&list, &node3, NEXT_OFFSET);
    DDAtomicListReverse(&list, NEXT_OFFSET);
    
    // LIFO order: popped in same order they were inserted
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node1, nil);
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node2, nil);
    STAssertEquals(DDAtomicListPop(&list, NEXT_OFFSET), (void*)&node3, nil);
    STAssertEquals(list, NULL, nil);
}

@end
