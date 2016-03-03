//
//  GameViewController.m
//
//  Created by Borna Noureddin.
//  Copyright (c) 2015 BCIT. All rights reserved.
//

#import "GameViewController.h"
#import <OpenGLES/ES2/glext.h>
#import "MMaze.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Shader uniform indices
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_MODELVIEW_MATRIX,
    /* more uniforms needed here... */
    UNIFORM_TEXTURE,
    UNIFORM_FLASHLIGHT_POSITION,
    UNIFORM_DIFFUSE_LIGHT_POSITION,
    UNIFORM_SHININESS,
    UNIFORM_AMBIENT_COMPONENT,
    UNIFORM_DIFFUSE_COMPONENT,
    UNIFORM_SPECULAR_COMPONENT,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface GameViewController () {
    GLuint _program;
    
    // Shader uniforms
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix3 _normalMatrix;
    
    // Lighting parameters
    /* specify lighting parameters here...e.g., GLKVector3 flashlightPosition; */
    GLKVector3 flashlightPosition;
    GLKVector3 diffuseLightPosition;
    GLKVector4 diffuseComponent;
    float shininess;
    GLKVector4 specularComponent;
    GLKVector4 ambientComponent;
    
    // Transformation parameters
    float _rotation;
    float xRot, yRot;
    CGPoint dragStart;
    
    // Shape vertices, etc. and textures
    GLfloat *vertices, *normals, *texCoords;
    GLuint numIndices, *indices;
    /* texture parameters ??? */
    GLuint crateTexture, *_textures;
    
    // GLES buffer IDs
    GLuint _vertexArray;
    GLuint _vertexBuffers[3];
    GLuint _indexBuffer;
    
    MMaze* _maze;
    int _numWalls;
    
    GLuint _floorTexture;
    GLuint _wallTextures[ 4 ];
}

@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up iOS gesture recognizers
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTap];
    
    UIPanGestureRecognizer *rotObj = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(doRotate:)];
    rotObj.minimumNumberOfTouches = 1;
    rotObj.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:rotObj];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    // Set up UI parameters
    xRot = yRot = 30 * M_PI / 180;
    
    _maze = [[MMaze alloc] initRows: 5 initCols: 5];
    [_maze create];
    
    // Set up GL
    [self setupGL];
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Load shaders
    [self loadShaders];
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "modelViewMatrix");
    /* more needed here... */
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "texture");
    uniforms[UNIFORM_FLASHLIGHT_POSITION] = glGetUniformLocation(_program, "flashlightPosition");
    uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION] = glGetUniformLocation(_program, "diffuseLightPosition");
    uniforms[UNIFORM_SHININESS] = glGetUniformLocation(_program, "shininess");
    uniforms[UNIFORM_AMBIENT_COMPONENT] = glGetUniformLocation(_program, "ambientComponent");
    uniforms[UNIFORM_DIFFUSE_COMPONENT] = glGetUniformLocation(_program, "diffuseComponent");
    uniforms[UNIFORM_SPECULAR_COMPONENT] = glGetUniformLocation(_program, "specularComponent");
    
    // Set up lighting parameters
    /* set values, e.g., flashlightPosition = GLKVector3Make(0.0, 0.0, 1.0); */
    flashlightPosition = GLKVector3Make(0.0, 0.0, 1.0);
    diffuseLightPosition = GLKVector3Make(0.0, 1.0, 0.0);
    diffuseComponent = GLKVector4Make(1, 1, 1, 1.0);
    shininess = 200.0;
    specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    ambientComponent = GLKVector4Make(0.2, 0.2, 0.2, 1.0);
    
    // Initialize GL and get buffers
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(3, _vertexBuffers);
    glGenBuffers(1, &_indexBuffer);
    
    // Generate vertices
    // Initialize GL and get buffers
    
    _floorTexture = [self setupTexture: @"floor.jpg"];
    _wallTextures[ 0 ] = [self setupTexture: @"wall0.jpg"];
    _wallTextures[ 1 ] = [self setupTexture: @"wall1.jpg"];
    _wallTextures[ 2 ] = [self setupTexture: @"wall2.jpg"];
    _wallTextures[ 3 ] = [self setupTexture: @"wall3.jpg"];
    
    glFrontFace( GL_CW );
    glCullFace( GL_BACK );
    glEnable( GL_CULL_FACE );
    glEnable( GL_DEPTH_TEST );
    
    if ( _maze )
    {
        const int numCells = _maze.rows * _maze.cols;
        
        GLfloat* pos = vertices = new GLfloat[ 3 * 3 * 2 * 5 * numCells ];
        GLfloat* norm = normals = new GLfloat[ 3 * 3 * 2 * 5 * numCells ];
        GLfloat* tex = texCoords = new GLfloat[ 2 * 3 * 2 * 5 * numCells ];
        GLuint* ttx = _textures = new GLuint[ numCells * 5 * 2 ];
        //GLfloat vertPos[ 6 * 3 * 2 * 4 * 4 * 4 ];
        
        const GLfloat width = 1;
        const GLfloat offX = (width * _maze.cols) / 2.0f;
        const GLfloat offZ = (width * _maze.rows) / 2.0f;
        
        const GLfloat y0 = 0;
        const GLfloat y1 = width;
        
        int p = 0;
        int n = 0;
        int t = 0;
        int v = 0;
        for ( int z = 0; z < _maze.rows; z++ )
        {
            const GLfloat z0 = -(width * z - offZ);
            const GLfloat z1 = z0 - width;
            
            for ( int x = 0; x < _maze.cols; x++ )
            {
                const GLfloat x0 = width * x - offX;
                const GLfloat x1 = x0 + width;
                
                if ( true ) // floor
                {
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    ttx[ v++ ] = _floorTexture;
                    
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    ttx[ v++ ] = _floorTexture;
                }
                
                MazeCell cell = [_maze cellX: x cellY: z];
                
                if ( cell.northWallPresent )
                {
                    GLuint texture = _wallTextures[ 0 ];
                    if ( cell.westWallPresent == cell.eastWallPresent )
                        texture = _wallTextures[ 1 ];
                    else if ( cell.westWallPresent )
                        texture = _wallTextures[ 2 ];
                    else if ( cell.eastWallPresent )
                        texture = _wallTextures[ 3 ];
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    ttx[ v++ ] = texture;
                    
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    ttx[ v++ ] = texture;
                }
                
                if ( cell.southWallPresent )
                {
                    GLuint texture = _wallTextures[ 0 ];
                    if ( cell.westWallPresent == cell.eastWallPresent )
                        texture = _wallTextures[ 1 ];
                    else if ( cell.westWallPresent )
                        texture = _wallTextures[ 3 ];
                    else if ( cell.eastWallPresent )
                        texture = _wallTextures[ 2 ];
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    ttx[ v++ ] = texture;
                    
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = -1;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    ttx[ v++ ] = texture;
                }
                
                if ( cell.eastWallPresent )
                {
                    GLuint texture = _wallTextures[ 0 ];
                    if ( cell.northWallPresent == cell.southWallPresent )
                        texture = _wallTextures[ 1 ];
                    else if ( cell.northWallPresent )
                        texture = _wallTextures[ 2 ];
                    else if ( cell.southWallPresent )
                        texture = _wallTextures[ 3 ];
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    ttx[ v++ ] = texture;
                    
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x1;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = -1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    ttx[ v++ ] = texture;
                }
                
                if ( cell.westWallPresent )
                {
                    GLuint texture = _wallTextures[ 0 ];
                    if ( cell.northWallPresent == cell.southWallPresent )
                        texture = _wallTextures[ 1 ];
                    else if ( cell.northWallPresent )
                        texture = _wallTextures[ 3 ];
                    else if ( cell.southWallPresent )
                        texture = _wallTextures[ 2 ];
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    ttx[ v++ ] = texture;
                    
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y1;
                    pos[ p++ ] = z1;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 0;
                    tex[ t++ ] = 1;
                    
                    pos[ p++ ] = x0;
                    pos[ p++ ] = y0;
                    pos[ p++ ] = z0;
                    norm[ n++ ] = 1;
                    norm[ n++ ] = 0;
                    norm[ n++ ] = 0;
                    tex[ t++ ] = 1;
                    tex[ t++ ] = 0;
                    
                    ttx[ v++ ] = texture;
                }
            }
        }
        _numWalls = v / 2;
        numIndices = p / 3;
        indices = new GLuint[ numIndices ];
        
        for ( int i = 0; i < numIndices; i++ )
            indices[ i ] = i;
        
        
        glBindBuffer( GL_ARRAY_BUFFER, _vertexBuffers[ 0 ] );
        glBufferData( GL_ARRAY_BUFFER, p * sizeof( GLfloat ), vertices, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribPosition );
        glVertexAttribPointer( GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ARRAY_BUFFER, _vertexBuffers[ 1 ] );
        glBufferData( GL_ARRAY_BUFFER, n * sizeof( GLfloat ), normals, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribNormal );
        glVertexAttribPointer( GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ARRAY_BUFFER, _vertexBuffers[ 2 ] );
        glBufferData( GL_ARRAY_BUFFER, t * sizeof( GLfloat ), texCoords, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribTexCoord0 );
        glVertexAttribPointer( GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _indexBuffer );
        glBufferData( GL_ELEMENT_ARRAY_BUFFER, sizeof(int) * numIndices, indices, GL_STATIC_DRAW );
        
        glBindVertexArrayOES( 0 );
    }
    
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture( GL_TEXTURE_2D, _floorTexture );
    glUniform1i( uniforms[ UNIFORM_TEXTURE ], 0 );
    
    /*int numVerts;
    numIndices = generateSphere(50, 1, &vertices, &normals, &texCoords, &indices, &numVerts);
    //    numIndices = generateCube(1.5, &vertices, &normals, &texCoords, &indices, &numVerts);
    
    // Set up GL buffers
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numIndices, indices, GL_STATIC_DRAW);
    
    glBindVertexArrayOES(0);
    
    // Load in and set texture
    // use setupTexture to create crate texture
    crateTexture = [self setupTexture:@"crate.jpg"];
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, crateTexture);
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);*/
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Delete GL buffers
    glDeleteBuffers(3, _vertexBuffers);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    // Delete vertices buffers
    if (vertices)
        free(vertices);
    if (indices)
        free(indices);
    if (normals)
        free(normals);
    if (texCoords)
        free(texCoords);
    
    // Delete shader program
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


#pragma mark - iOS gesture events

- (IBAction)doSingleTap:(UITapGestureRecognizer *)recognizer
{
    dragStart = [recognizer locationInView:self.view];
}

- (IBAction)doRotate:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        CGPoint newPt = [recognizer locationInView:self.view];
        yRot = (newPt.x - dragStart.x) * M_PI / 180;
        xRot = (newPt.y - dragStart.y) * M_PI / 180;
    }
}


#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    // Set up base model view matrix (place camera)
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    // Set up model view matrix (place model in world)
    _modelViewMatrix = GLKMatrix4Identity;
    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, xRot, 1.0f, 0.0f, 0.0f);
    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, yRot, 0.0f, 1.0f, 0.0f);
    _modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    _modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, _modelViewMatrix);
    
    // Calculate normal matrix
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_modelViewMatrix), NULL);
    
    // Calculate projection matrix
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, _modelViewMatrix);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // Clear window
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Select VAO and shaders
    glBindVertexArrayOES(_vertexArray);
    glUseProgram(_program);
    
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    /* set lighting parameters... */
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    
    // Select VBO and draw
    
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _indexBuffer );
    for ( int i = 0; i < _numWalls * 2; i++ )
    {
        glBindTexture( GL_TEXTURE_2D, _textures[ i ] );
        glDrawElements( GL_TRIANGLES, 3, GL_UNSIGNED_INT, (GLuint*)(i * 3 * sizeof( GLuint )) );
    }
    
    //glBindTexture( GL_TEXTURE_2D, _textures[ i ] );
    //glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _indexBuffer );
    //glDrawElements( GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0 );
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texCoordIn");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}



#pragma mark - Utility functions

// Load in and set up texture image (adapted from Ray Wenderlich)
- (GLuint)setupTexture:(NSString *)fileName
{
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte *spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}

// Generate vertices, normals, texture coordinates and indices for cube
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int generateCube(float scale, GLfloat **vertices, GLfloat **normals,
                 GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    int numVertices = 24;
    int numIndices = 36;
    
    GLfloat cubeVerts[] =
    {
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        -0.5f,  0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f, 0.5f,
        -0.5f,  0.5f, 0.5f,
        0.5f,  0.5f, 0.5f,
        0.5f, -0.5f, 0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        -0.5f,  0.5f,  0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
    };
    
    GLfloat cubeNormals[] =
    {
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
    };
    
    GLfloat cubeTex[] =
    {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = (float*) malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *vertices, cubeVerts, sizeof ( cubeVerts ) );
        
        for ( i = 0; i < numVertices * 3; i++ )
        {
            ( *vertices ) [i] *= scale;
        }
    }
    
    if ( normals != NULL )
    {
        *normals = (float*) malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *normals, cubeNormals, sizeof ( cubeNormals ) );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = (float*) malloc ( sizeof ( GLfloat ) * 2 * numVertices );
        memcpy ( *texCoords, cubeTex, sizeof ( cubeTex ) ) ;
    }
    
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint cubeIndices[] =
        {
            0, 2, 1,
            0, 3, 2,
            4, 5, 6,
            4, 6, 7,
            8, 9, 10,
            8, 10, 11,
            12, 15, 14,
            12, 14, 13,
            16, 17, 18,
            16, 18, 19,
            20, 23, 22,
            20, 22, 21
        };
        
        *indices = (uint*) malloc ( sizeof ( GLuint ) * numIndices );
        memcpy ( *indices, cubeIndices, sizeof ( cubeIndices ) );
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

// Generate vertices, normals, texture coordinates and indices for sphere
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int generateSphere(int numSlices, float radius, GLfloat **vertices, GLfloat **normals,
                   GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = ( 2.0f * M_PI ) / ( ( float ) numSlices );
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = (float*) malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( normals != NULL )
    {
        *normals = (float*) malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = (float*) malloc ( sizeof ( GLfloat ) * 2 * numVertices );
    }
    
    if ( indices != NULL )
    {
        *indices = (uint*) malloc ( sizeof ( GLuint ) * numIndices );
    }
    
    for ( i = 0; i < numParallels + 1; i++ )
    {
        for ( j = 0; j < numSlices + 1; j++ )
        {
            int vertex = ( i * ( numSlices + 1 ) + j ) * 3;
            
            if ( vertices )
            {
                ( *vertices ) [vertex + 0] = radius * sinf ( angleStep * ( float ) i ) *
                sinf ( angleStep * ( float ) j );
                ( *vertices ) [vertex + 1] = radius * cosf ( angleStep * ( float ) i );
                ( *vertices ) [vertex + 2] = radius * sinf ( angleStep * ( float ) i ) *
                cosf ( angleStep * ( float ) j );
            }
            
            if ( normals )
            {
                ( *normals ) [vertex + 0] = ( *vertices ) [vertex + 0] / radius;
                ( *normals ) [vertex + 1] = ( *vertices ) [vertex + 1] / radius;
                ( *normals ) [vertex + 2] = ( *vertices ) [vertex + 2] / radius;
            }
            
            if ( texCoords )
            {
                int texIndex = ( i * ( numSlices + 1 ) + j ) * 2;
                ( *texCoords ) [texIndex + 0] = ( float ) j / ( float ) numSlices;
                ( *texCoords ) [texIndex + 1] = ( 1.0f - ( float ) i ) / ( float ) ( numParallels - 1 );
            }
        }
    }
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint *indexBuf = ( *indices );
        
        for ( i = 0; i < numParallels ; i++ )
        {
            for ( j = 0; j < numSlices; j++ )
            {
                *indexBuf++  = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

// >>>

@end
