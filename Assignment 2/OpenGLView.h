//
//  OpenGLView.h
//  Assignment 2
//
//  Created by Andrew Meckling on 2016-02-24.
//  Copyright © 2016 Andrew Meckling. All rights reserved.
//

#ifndef OpenGLView_h
#define OpenGLView_h

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface OpenGLView : UIView
{
    CAEAGLLayer*   mEaglLayer;
    EAGLContext*  mContext;
    GLuint        mColorRenderBuffer;
}

+ (Class) layerClass;

- (void) setupLayer;

- (void) setupContext;

- (void) setupRenderBuffer;

- (void) setupFrameBuffer;

- (void) render;

@end


#endif /* OpenGLView_h */
