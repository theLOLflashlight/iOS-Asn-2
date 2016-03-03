//
//  OpenGLView.m
//  Assignment 2
//
//  Created by Andrew Meckling on 2016-02-24.
//  Copyright © 2016 Andrew Meckling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenGLView.h"

@interface OpenGLView ()
{
    
}

@end

@implementation OpenGLView

+ (Class) layerClass;
{
    return [CAEAGLLayer class];
}

- (void) setupLayer
{
    mEaglLayer = (CAEAGLLayer*) self.layer;
    mEaglLayer.opaque = YES;
}

- (void) setupContext
{
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    
    mContext = [[EAGLContext alloc] initWithAPI: api];
    
    if ( !mContext )
    {
        NSLog( @"Failed to initialize OpenGLES 2.0 context" );
        exit( 1 );
    }
    
    if ( ![EAGLContext setCurrentContext: mContext] )
    {
        NSLog( @"Failed to set current OpenGL context" );
        exit( 1 );
    }
}

- (void) setupRenderBuffer
{
    glGenRenderbuffers( 1, &mColorRenderBuffer );
    glBindRenderbuffer( GL_RENDERBUFFER, mColorRenderBuffer );
    [mContext renderbufferStorage: GL_RENDERBUFFER fromDrawable: mEaglLayer];
}

- (void) setupFrameBuffer
{
    GLuint framebuffer;
    glGenFramebuffers( 1, &framebuffer );
    glBindFramebuffer( GL_FRAMEBUFFER, framebuffer );
    glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_RENDERBUFFER, mColorRenderBuffer );
}

- (void) render
{
    glClearColor( 0, 104.0/255.0, 55.0/255.0, 1.0 );
    glClear( GL_COLOR_BUFFER_BIT );
    [mContext presentRenderbuffer: GL_RENDERBUFFER];
}

// Replace initWithFrame with this
- (id) initWithFrame:( CGRect ) frame
{
    self = [super initWithFrame: frame];
    if ( self )
    {
        [self setupLayer];
        [self setupContext];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self render];
    }
    return self;
}

// Replace dealloc method with this
- (void) dealloc
{
    //[mContext release];
    mContext = nil;
    //[super dealloc];
}


@end