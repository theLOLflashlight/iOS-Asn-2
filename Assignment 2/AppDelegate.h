//
//  AppDelegate.h
//  Assignment 2
//
//  Created by Andrew Meckling on 2016-02-24.
//  Copyright © 2016 Andrew Meckling. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenGLView.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    OpenGLView* mGlView;
}

@property (nonatomic, retain) IBOutlet OpenGLView* glView;

@property (strong, nonatomic) UIWindow* window;


@end

