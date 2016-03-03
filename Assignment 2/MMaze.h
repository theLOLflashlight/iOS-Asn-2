//
//  MixTest.h
//  MixedLanguages
//
//  Created by Borna Noureddin on 2013-10-09.
//  Copyright (c) 2013 Borna Noureddin. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "maze.h"

struct MazeClass;

@interface MMaze : NSObject
{
    @private
    struct MazeClass* mazeObject;
}

- (id) initRows:( float ) r
       initCols:( float ) c;

@property (nonatomic) int rows;						// size of maze
@property (nonatomic) int cols;

-(MazeCell) cellX:( int ) x
            cellY:( int ) y;

-(void) create;	// creates a random maze

@end
