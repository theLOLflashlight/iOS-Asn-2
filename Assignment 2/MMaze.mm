//
//  MixTest.m
//  MixedLanguages
//
//  Created by Borna Noureddin on 2013-10-09.
//  Copyright (c) 2013 Borna Noureddin. All rights reserved.
//

#import "MMaze.h"

struct MazeClass
{
    Maze maze;
    
    MazeClass( int r, int c )
        : maze( r, c )
    {
    }
    
};

@implementation MMaze

- (id) init
{
    self = [super init];
    if (self) {
        mazeObject = new MazeClass( 4, 4 );
    }
    return self;
}

- (id) initRows:( float ) r
       initCols:( float ) c
{
    self = [super init];
    if (self) {
        mazeObject = new MazeClass( r, c );
    }
    return self;
}

-(int) rows
{
    return mazeObject->maze.rows;
}

-(int) cols
{
    return mazeObject->maze.cols;
}

-(MazeCell) cellX:( int ) x
            cellY:( int ) y
{
    return mazeObject->maze.GetCell( x, y );
}

-(void) create
{
    mazeObject->maze.Create();
}


@end
