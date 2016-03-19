//
//  GameViewController.h
//  Assignment 2
//
//  Created by Andrew Meckling on 2016-02-24.
//  Copyright © 2016 Andrew Meckling. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface GameViewController : GLKViewController

@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *singleTapRecg;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *doubleTapRecg;

@end
