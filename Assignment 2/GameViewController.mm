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
    GLKMatrix4 _cameraMatrix;
    GLKMatrix4 _mazeMatrix, _crateMatrix;
    GLKMatrix3 _mazeNormalMatrix, _crateNormalMatrix;
    
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
    GLfloat *crateVerts, *crateNorms, *crateTexCoords;
    GLuint crateNumIndices, *crateIndices;
    /* texture parameters ??? */
    GLuint crateTexture, *_textures;
    
    // GLES buffer IDs
    GLuint _mazeArray, _crateArray;
    GLuint _mazeBuffers[3], _crateBuffers[3];
    GLuint _mazeIndexBuffer, _crateIndexBuffer;
    
    MMaze* _maze;
    GLfloat *mazeVerts, *mazeNorms, *mazeTexCoords;
    GLuint _numWalls, mazeNumIndices, *mazeIndices;
    
    GLuint _floorTexture;
    GLuint _wallTextures[ 4 ];
    
    GLKVector3 _cameraPosition;
    CGPoint* _lastTouchPoint;
    BOOL _daytimeOn;
    BOOL _flashlightOn;
    BOOL _fogOn;
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
    
    _lastTouchPoint = nil;
    
    // Set up iOS gesture recognizers
    /*UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTap];
    
    UIPanGestureRecognizer *rotObj = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(doRotate:)];
    rotObj.minimumNumberOfTouches = 1;
    rotObj.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:rotObj];*/
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    // Set up UI parameters
    xRot = yRot = 0;
    
    _cameraPosition = { 0, -0.5f, 0 };
    
    _maze = [[MMaze alloc] initRows: 10 initCols: 10];
    [_maze create];
    
    [_singleTapRecg requireGestureRecognizerToFail: _doubleTapRecg];
    
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
    flashlightPosition = GLKVector3Make(0.0, 0.0, 0.0);
    diffuseLightPosition = GLKVector3Make(0.0, 1.0, 0.0);
    diffuseComponent = GLKVector4Make(1, 1, 1, 1.0);
    shininess = 200.0;
    specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    ambientComponent = GLKVector4Make(0.2, 0.2, 0.2, 1.0);
    
    // Initialize GL and get buffers
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_mazeArray);
    glBindVertexArrayOES(_mazeArray);
    
    glGenBuffers(3, _mazeBuffers);
    glGenBuffers(1, &_mazeIndexBuffer);
    
    // Generate vertices
    // Initialize GL and get buffers
    
    _floorTexture = [self setupTexture: @"floor.jpg"];
    _wallTextures[ 0 ] = [self setupTexture: @"wall0.jpg"];
    _wallTextures[ 1 ] = [self setupTexture: @"wall1.jpg"];
    _wallTextures[ 2 ] = [self setupTexture: @"wall2.jpg"];
    _wallTextures[ 3 ] = [self setupTexture: @"wall3.jpg"];
    crateTexture = [self setupTexture: @"crate.jpg"];
    
    glCullFace( GL_BACK );
    glEnable( GL_CULL_FACE );
    glEnable( GL_DEPTH_TEST );
    
    if ( _maze )
    {
        const int numCells = _maze.rows * _maze.cols;
        
        GLfloat* pos = mazeVerts = new GLfloat[ 3 * 3 * 2 * 5 * numCells ];
        GLfloat* norm = mazeNorms = new GLfloat[ 3 * 3 * 2 * 5 * numCells ];
        GLfloat* tex = mazeTexCoords = new GLfloat[ 2 * 3 * 2 * 5 * numCells ];
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
                
                if ( cell.northWallPresent && (z == 0 || [_maze cellX: x cellY: z - 1].southWallPresent) )
                {
                    int texI = 0;
                    if ( x > 0
                        && [_maze cellX: x - 1 cellY: z].northWallPresent
                        && (z == 0 || [_maze cellX: x - 1 cellY: z - 1].southWallPresent) )
                        texI += 1;
                    if ( x < _maze.cols - 1
                        && [_maze cellX: x + 1 cellY: z].northWallPresent
                        && (z == 0 || [_maze cellX: x + 1 cellY: z - 1].southWallPresent) )
                        texI += 2;
                    
                    GLuint texture = _wallTextures[ texI ];
                    
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
                
                if ( cell.southWallPresent && (z == _maze.rows - 1 || [_maze cellX: x cellY: z + 1].northWallPresent))
                {
                    int texI = 0;
                    if ( x > 0
                        && [_maze cellX: x - 1 cellY: z].southWallPresent
                        && (z == _maze.rows - 1 || [_maze cellX: x - 1 cellY: z + 1].northWallPresent) )
                        texI += 2;
                    if ( x < _maze.cols - 1
                        && [_maze cellX: x + 1 cellY: z].southWallPresent
                        && (z == _maze.rows - 1 || [_maze cellX: x + 1 cellY: z + 1].northWallPresent) )
                        texI += 1;
                    
                    GLuint texture = _wallTextures[ texI ];
                    
                    
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
                
                if ( cell.eastWallPresent && (x == _maze.cols - 1 || [_maze cellX: x + 1 cellY: z].westWallPresent) )
                {
                    int texI = 0;
                    if ( z > 0
                        && [_maze cellX: x cellY: z - 1].eastWallPresent
                        && (x == _maze.cols - 1 || [_maze cellX: x + 1 cellY: z - 1].westWallPresent) )
                        texI += 1;
                    if ( z < _maze.rows - 1
                        && [_maze cellX: x cellY: z + 1].eastWallPresent
                        && (x == _maze.cols - 1 || [_maze cellX: x + 1 cellY: z + 1].westWallPresent) )
                        texI += 2;
                    
                    GLuint texture = _wallTextures[ texI ];
                    
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
                
                if ( cell.westWallPresent && (x == 0 || [_maze cellX: x - 1 cellY: z].eastWallPresent) )
                {
                    int texI = 0;
                    if ( z > 0
                        && [_maze cellX: x cellY: z - 1].westWallPresent
                        && (x == 0 || [_maze cellX: x - 1 cellY: z - 1].eastWallPresent) )
                        texI += 2;
                    if ( z < _maze.rows - 1
                        && [_maze cellX: x cellY: z + 1].westWallPresent
                        && (x == 0 || [_maze cellX: x - 1 cellY: z + 1].eastWallPresent) )
                        texI += 1;
                    
                    GLuint texture = _wallTextures[ texI ];
                    
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
        mazeNumIndices = p / 3;
        mazeIndices = new GLuint[ mazeNumIndices ];
        
        for ( int i = 0; i < mazeNumIndices; i++ )
            mazeIndices[ i ] = i;
        
        
        glBindBuffer( GL_ARRAY_BUFFER, _mazeBuffers[ 0 ] );
        glBufferData( GL_ARRAY_BUFFER, p * sizeof( GLfloat ), mazeVerts, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribPosition );
        glVertexAttribPointer( GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ARRAY_BUFFER, _mazeBuffers[ 1 ] );
        glBufferData( GL_ARRAY_BUFFER, n * sizeof( GLfloat ), mazeNorms, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribNormal );
        glVertexAttribPointer( GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ARRAY_BUFFER, _mazeBuffers[ 2 ] );
        glBufferData( GL_ARRAY_BUFFER, t * sizeof( GLfloat ), mazeTexCoords, GL_STATIC_DRAW );
        glEnableVertexAttribArray( GLKVertexAttribTexCoord0 );
        glVertexAttribPointer( GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof( float ), 0 );
        
        glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _mazeIndexBuffer );
        glBufferData( GL_ELEMENT_ARRAY_BUFFER, sizeof(int) * mazeNumIndices, mazeIndices, GL_STATIC_DRAW );
        
        glBindVertexArrayOES( 0 );
    }
    
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture( GL_TEXTURE_2D, _floorTexture );
    glUniform1i( uniforms[ UNIFORM_TEXTURE ], 0 );
    
    glGenVertexArraysOES(1, &_crateArray);
    glBindVertexArrayOES(_crateArray);
    
    glGenBuffers(3, _crateBuffers);
    glGenBuffers(1, &_crateIndexBuffer);
    
    int numVerts;
    //numIndices = generateSphere(50, 1, &vertices, &normals, &texCoords, &indices, &numVerts);
    crateNumIndices = generateCube(1.5, &crateVerts, &crateNorms, &crateTexCoords, &crateIndices, &numVerts);
    
    // Set up GL buffers
    glBindBuffer( GL_ARRAY_BUFFER, _crateBuffers[ 0 ] );
    glBufferData( GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, crateVerts, GL_STATIC_DRAW );
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer( GL_ARRAY_BUFFER, _crateBuffers[ 1 ] );
    glBufferData( GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, crateNorms, GL_STATIC_DRAW );
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer( GL_ARRAY_BUFFER, _crateBuffers[ 2 ] );
    glBufferData( GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, crateTexCoords, GL_STATIC_DRAW );
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _crateIndexBuffer );
    glBufferData( GL_ELEMENT_ARRAY_BUFFER, sizeof(int) * crateNumIndices, crateIndices, GL_STATIC_DRAW );
    
    glBindVertexArrayOES(0);
    
    // Load in and set texture
    // use setupTexture to create crate texture
    //crateTexture = [self setupTexture:@"crate.jpg"];
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture( GL_TEXTURE_2D, crateTexture );
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Delete GL buffers
    glDeleteBuffers(3, _mazeBuffers);
    glDeleteBuffers(1, &_mazeIndexBuffer);
    glDeleteVertexArraysOES(1, &_mazeArray);
    
    glDeleteBuffers(3, _crateBuffers);
    glDeleteBuffers(1, &_crateIndexBuffer);
    glDeleteVertexArraysOES(1, &_crateArray);
    
    // Delete vertices buffers
    delete crateVerts;
    delete crateNorms;
    delete crateTexCoords;
    delete crateIndices;
    
    delete mazeVerts;
    delete mazeNorms;
    delete mazeTexCoords;
    delete mazeIndices;
    
    // Delete shader program
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


#pragma mark - iOS gesture events


- (IBAction) handlePan:( UIPanGestureRecognizer* ) recognizer
{
    CGPoint translation = [recognizer translationInView: self.view];
    
    if ( _lastTouchPoint == nil )
        return;

    if ( recognizer.numberOfTouches == 1 )
    {
        xRot += (translation.y - _lastTouchPoint->y) * 0.01f;
        yRot += (translation.x - _lastTouchPoint->x) * 0.01f;
    }
    /*else if ( recognizer.numberOfTouches >= 2 )
    {
        _positionX += (translation.x - _lastTouchPoint->x) * 0.01f;
        _positionY -= (translation.y - _lastTouchPoint->y) * 0.01f;
    }*/
    
    *_lastTouchPoint = translation;
}

- (IBAction) doSingleTap:( UITapGestureRecognizer* ) sender
{
    _cameraPosition.x -= sinf( yRot );
    _cameraPosition.z += cosf( yRot );
    
    delete _lastTouchPoint;
    _lastTouchPoint = nil;
}

- (IBAction) doDoubleTap:( UITapGestureRecognizer* ) recognizer
{
    _cameraPosition = { 0, -0.5f, 0 };
    xRot = yRot = 0;
    
    delete _lastTouchPoint;
    _lastTouchPoint = nil;
}

-(void) touchesBegan:( NSSet* ) touches
           withEvent:( UIEvent* ) event
{
    UITouch* touch = (UITouch*) [touches anyObject];
    
    if ( touch != nil )
    {
        _lastTouchPoint = new CGPoint;
        *_lastTouchPoint = touch.accessibilityActivationPoint;
    }
}

-(void) touchesEnded:( NSSet* ) touches
           withEvent:( UIEvent* ) event
{
    delete _lastTouchPoint;
    _lastTouchPoint = nil;
}


- (IBAction) daytimeSwitch:(UISwitch*) sender
{
    _daytimeOn = [sender isOn];
}

- (IBAction) flashlightSwitch:(UISwitch*) sender
{
    _flashlightOn = [sender isOn];
}

- (IBAction) fogSwitch:(UISwitch*) sender
{
    _fogOn = [sender isOn];
}


#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    // Set up base model view matrix (place camera)
    GLKMatrix4 baseCameraMatrix = GLKMatrix4MakeRotation( xRot, 1.0f, 0.0f, 0.0f );
    baseCameraMatrix = GLKMatrix4Rotate( baseCameraMatrix, yRot, 0.0f, 1.0f, 0.0f );
    baseCameraMatrix = GLKMatrix4Translate( baseCameraMatrix, _cameraPosition.x, _cameraPosition.y, _cameraPosition.z );
    
    //GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation( _cameraPosition.x, _cameraPosition.y, _cameraPosition.z );
    //baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, yRot, 0.0f, 1.0f, 0.0f);
    
    // Set up model view matrix (place model in world)
    _mazeMatrix = GLKMatrix4Identity;
    //_mazeMatrix = GLKMatrix4Rotate( _mazeMatrix, -xRot, 1.0f, 0.0f, 0.0f );
    //_mazeMatrix = GLKMatrix4Rotate( _mazeMatrix, -yRot, 0.0f, 1.0f, 0.0f );
    //_modelViewMatrix = GLKMatrix4Rotate(_modelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    _mazeMatrix = GLKMatrix4Multiply( baseCameraMatrix, _mazeMatrix );
    
    // Calculate normal matrix
    _mazeNormalMatrix = GLKMatrix3InvertAndTranspose( GLKMatrix4GetMatrix3( _mazeMatrix ), NULL );
    
    _crateMatrix = GLKMatrix4MakeScale( 0.5f, 0.5f, 0.5f );
    _crateMatrix = GLKMatrix4Rotate( _crateMatrix, _rotation, 0, 1, 0 );
    _crateMatrix = GLKMatrix4Translate( _crateMatrix, 0, -0.5f, 0 );
    _crateMatrix = GLKMatrix4Multiply( baseCameraMatrix, _crateMatrix );
    
    // Calculate normal matrix
    _crateNormalMatrix = GLKMatrix3InvertAndTranspose( GLKMatrix4GetMatrix3( _crateMatrix ), NULL );
    
    // Calculate projection matrix
    float aspect = fabsf( self.view.bounds.size.width / self.view.bounds.size.height );
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective( GLKMathDegreesToRadians( 90.0f ), aspect, 0.1f, 10.0f );
    
    _cameraMatrix = GLKMatrix4Multiply( projectionMatrix, baseCameraMatrix );
    
    flashlightPosition = _cameraPosition;
    flashlightPosition.x -= cosf( yRot );
    flashlightPosition.y -= sinf( xRot );
    flashlightPosition.z += sinf( yRot );
    
    ambientComponent.r = _daytimeOn ? 0.8f : 0.3f;
    ambientComponent.g = _daytimeOn ? 0.8f : 0.3f;
    ambientComponent.b = _daytimeOn ? 0.75f : 0.4f;
    
    diffuseComponent.r = _daytimeOn ? 0.8f : 0.3f;
    diffuseComponent.g = _daytimeOn ? 0.8f : 0.3f;
    diffuseComponent.b = _daytimeOn ? 0.75f : 0.4f;
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // Clear window
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Select VAO and shaders
    glBindVertexArrayOES(_mazeArray);
    glUseProgram(_program);
    
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _cameraMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _mazeNormalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _mazeMatrix.m);
    /* set lighting parameters... */
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    
    glFrontFace( GL_CW );
    // Select VBO and draw
    
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _mazeIndexBuffer );
    for ( int i = 0; i < _numWalls * 2; i++ )
    {
        glBindTexture( GL_TEXTURE_2D, _textures[ i ] );
        glDrawElements( GL_TRIANGLES, 3, GL_UNSIGNED_INT, (GLuint*)(i * 3 * sizeof( GLuint )) );
    }
    
    glFrontFace( GL_CCW );
    glBindVertexArrayOES( _crateArray );
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _crateNormalMatrix.m);
    glUniformMatrix4fv( uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _crateMatrix.m );
    
    glBindTexture( GL_TEXTURE_2D, crateTexture );
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, _crateIndexBuffer );
    glDrawElements( GL_TRIANGLES, crateNumIndices, GL_UNSIGNED_INT, 0 );
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
