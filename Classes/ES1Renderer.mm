#import "ES1Renderer.h"
#import "ThreadPool.h"

@implementation ES1Renderer

// Create an ES 1.1 context
- (id) init
{
	if (self = [super init])
	{
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    if (!context || ![EAGLContext setCurrentContext:context])
		{
      [self release];
      return nil;
    }
		
		// Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer
		glGenFramebuffersOES(1, &defaultFramebuffer);
		glGenRenderbuffersOES(1, &colorRenderbuffer);
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
	}

	return self;
}

// Consider this 1 step of the game loop.
- (void) render
{
  // Replace the implementation of this method to do your own custom drawing
  GLfloat squareVertices[] = {
      -0.5f, -0.5f,
      0.5f,  -0.5f,
      -0.5f,  0.5f,
      0.5f,   0.5f,
  };
  GLubyte squareColors[] = {
      255, 255,   0, 255,
      0,   255, 255, 255,
      0,     0,   0,   0,
      255,   0, 255, 255,
  };
  
  [EAGLContext setCurrentContext:context];
  glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
  glViewport(0, 0, backingWidth, backingHeight);
  
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrthof(-1.0f, 1.0f, -1.5f, 1.5f, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);
  
  // Spins only when theere are background jobs
  glRotatef( 3.0f, 0.0f, 0.0f, 1.0f ) ;
  
  glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  
  glVertexPointer(2, GL_FLOAT, 0, squareVertices);
  glEnableClientState(GL_VERTEX_ARRAY);
  glColorPointer(4, GL_UNSIGNED_BYTE, 0, squareColors);
  glEnableClientState(GL_COLOR_ARRAY);
  
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  
  glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
  [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void) runFrame
{
  // create 2 WorkOrders:  one that does the ai work, and one that
  // does the rendering.
  
  bool threadingOn = 1 ;
  #define ITERATIONS 70000
  
  if( !threadingOn )
  {
    // Do the work directly on the main thread.
    for( int i = 0 ; i < 10 ; i++ )
    {
      // This is the code of the job.
      long long sum = 0 ;
      for( int j = 0 ; j < ITERATIONS ; j++ )
        sum += rand() ;
      //printf( "AI: The sum was %lld\n", sum ) ;
    
      sum=0;
      for( int j = 0 ; j < ITERATIONS ; j++ )
        sum += rand() ;
      //printf( "physics job: got %lld\n", sum ) ; // this makes no sense, its just code that runs.
    }
    
    [self render] ;
  }
  else
  {
    /// Use the threadPool.
    
    // Add a few workorders.  ORDER OF CREATION MATTERS, here
    // the AI workorder WILL RUN BEFORE the graphics workorder.
    WorkOrder *aiWo = threadPool->createNewWorkOrder( "AI" ) ;
    WorkOrder *physicsWo = new WorkOrder( "physics" ) ;
    
    // Just create a big bunch of like fake jobs
    // All 100 of the jobs added to each WorkOrder ARE parallelizable,
    // but the graphics jobs will run AFTER the ai jobs.
    for( int i = 0 ; i < 10 ; i++ )
    {
      aiWo->addJob( new Callback0( [](){ 
        // This is the code of the job.
        long long sum = 0 ;
        for( int j = 0 ; j < ITERATIONS ; j++ )
          sum += rand() ;
        //printf( "AI: The sum was %lld\n", sum ) ;
      } ) ) ;
      
      physicsWo->addJob( new Callback0( [](){
        long long sum = 0 ;
        for( int j = 0 ; j < ITERATIONS ; j++ )
          sum += rand() ;
        //printf( "physics job: got %lld\n", sum ) ; // this makes no sense, its just code that runs.
      } ) ) ;
    }
    
    aiWo->finishedSubmission() ;
    physicsWo->finishedSubmission() ;
    threadPool->addWorkOrder( physicsWo ) ;
    
    // The rendering is forced to go AFTER the ai comps, and the rendering
    // is also forced to run on the main thread.
    threadPool->wakeAll() ;
    
    // The main thread should be made to run worker jobs too.
    threadPool->runJobs() ;
    
    threadPool->addJobForMainThread( new Callback0( [self](){
      [self render] ;
    } ) ) ;
    
    // The main thread (me) must invoke this
    // here I wait until all other jobs are finished.
    // BUSY WAIT UNTIL ALL JOBS ARE DONE
    threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ; // SYNCHRONIZE
    threadPool->mainThreadRunJobs() ; // basically rendering and buffer flip that should be done on the main thread
    // (could use EAGL Shared Groups, but I do it this way here)
  }
}

- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer
{	
	// Allocate color buffer backing based on the current layer size
  glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
  [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
  glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
  if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
    return NO;
  }
    
  return YES;
}

- (void) dealloc
{
	// Tear down GL
	if (defaultFramebuffer)
	{
		glDeleteFramebuffersOES(1, &defaultFramebuffer);
		defaultFramebuffer = 0;
	}
	
	if (colorRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &colorRenderbuffer);
		colorRenderbuffer = 0;
	}
	
	// Tear down context
	if ([EAGLContext currentContext] == context)
      [EAGLContext setCurrentContext:nil];
	
	[context release];
	context = nil;
  [super dealloc] ;
}

@end
