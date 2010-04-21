/*
 *  DDAtomicList.h
 *  DDAudioQueue
 *
 *  Created by Dave Dribin on 4/20/10.
 *  Copyright 2010 Bit Maki, Inc. All rights reserved.
 *
 */

#include <stdlib.h>

// lockless and thread safe linked list utilities
// a NULL list is considered empty
typedef void * DDAtomicListRef;


// thread safe functions: may be called on a shared list from multiple threads with no locking
void DDAtomicListInsert(DDAtomicListRef * listPtr, void * node, size_t linkOffset);
DDAtomicListRef DDAtomicListSteal(DDAtomicListRef * listPtr);

// thread unsafe functions: must be called only on lists which other threads cannot access
void DDAtomicListReverse(DDAtomicListRef * listPtr, size_t linkOffset);
void *DDAtomicListPop(DDAtomicListRef * listPtr, size_t linkOffset); // returns NULL on empty list

/*
 * Based heavily on Mike Ash's RAAtomicList (included with RAOperatoinQueue),
 * but works a next pointer inside structures to avoid allocating and freeing
 * memory on insertion and pop.
 *
 * http://www.rogueamoeba.com/utm/2008/12/01/raoperationqueue-an-open-source-replacement-for-nsoperationqueue/
 */