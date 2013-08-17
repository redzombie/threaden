#import "ES1Renderer.h"
#import "ThreadPool.h"

vector<VertexPC> pcVertsA,pcVertsB ;
vector<VertexPNC> pncVerts ;

void drawPC( const vector<VertexPC>& verts, int start, int count, GLenum drawMode )
{
  if( !verts.size() ) return ;
  glEnableClientState( GL_VERTEX_ARRAY ) ;
  glEnableClientState( GL_COLOR_ARRAY ) ;
  
  glVertexPointer( 3, GL_FLOAT, sizeof( VertexPC ), &verts[0].pos ) ;
  glColorPointer( 4, GL_FLOAT, sizeof( VertexPC ), &verts[0].color ) ;
  glDrawArrays( drawMode, start, count ) ;

  glDisableClientState( GL_VERTEX_ARRAY ) ;
  glDisableClientState( GL_COLOR_ARRAY ) ;
}

void drawPC( const vector<VertexPC>& verts, GLenum drawMode )
{
  if( !verts.size() ) return ;
  glEnableClientState( GL_VERTEX_ARRAY ) ;
  glEnableClientState( GL_COLOR_ARRAY ) ;
  
  glVertexPointer( 3, GL_FLOAT, sizeof( VertexPC ), &verts[0].pos ) ;
  glColorPointer( 4, GL_FLOAT, sizeof( VertexPC ), &verts[0].color ) ;
  glDrawArrays( drawMode, 0, (int)verts.size() ) ;

  glDisableClientState( GL_VERTEX_ARRAY ) ;
  glDisableClientState( GL_COLOR_ARRAY ) ;
}

void drawPNC( const vector<VertexPNC>& verts, GLenum drawMode )
{
  if( !verts.size() ) return ;
  glEnableClientState( GL_VERTEX_ARRAY ) ;
  glEnableClientState( GL_NORMAL_ARRAY ) ;
  glEnableClientState( GL_COLOR_ARRAY ) ;
  
  glVertexPointer( 3, GL_FLOAT, sizeof( VertexPNC ), &verts[0].pos ) ;
  glNormalPointer( GL_FLOAT, sizeof( VertexPNC ), &verts[0].normal ) ;
  glColorPointer( 4, GL_FLOAT, sizeof( VertexPNC ), &verts[0].color ) ;
  
  glDrawArrays( drawMode, 0, (int)verts.size() ) ;
  
  glDisableClientState( GL_VERTEX_ARRAY ) ;
  glDisableClientState( GL_NORMAL_ARRAY ) ;
  glDisableClientState( GL_COLOR_ARRAY ) ;
  
}

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
  
  // Gen data
  for( int i = 0 ; i < 180000 ; i++ )
  {
    Vector3f p = Vector3f::random(-1.f,1.f) ;
    Vector3f dir = Vector3f::random(-1.f,1.f).normalize() ;
    
    addLine( pcVertsA, p, p+dir*0.05f, Vector4f::random() ) ;
  }
  pcVertsB=pcVertsA;//copy it
  
  threadingOn = 1 ;
  rot = Matrix3f::rotation( Vector3f::random(), randFloat( 0.01f, 0.02f ) ) ;
  draw=&pcVertsA, process = &pcVertsB ;
  
  return self;
}

- (void) setupTransformations
{
  glMatrixMode( GL_PROJECTION ) ;
  glLoadIdentity() ;
  glOrthof( -2.f, 2.f, -2.f, 2.f, -10.0f, 10.0f ) ;
  glMatrixMode( GL_MODELVIEW ) ;
}

// Stuff you must do prior to rendering (call on main thread)
- (void) prerender:(EAGLContext*)glContext
{
  //[EAGLContext setCurrentContext:glContext]; // you don't have to do this every frame.
  ///glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer); // SHARED.// you don't have to do this every frame.
  glViewport( 0, 0, backingWidth, backingHeight ) ;
  glClearColor( 0.25f, 0.25f, 0.25f, 1.0f ) ;
  glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
  
  [self setupTransformations];
}

// stuff you do after all rendering is complete (call on main thread)
- (void) flipBuffers
{
  glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);// you don't have to do this every frame.
  [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

// Process first, draw afterward.  If your app uses this mode,
// shut down your computer, go outside, and really think. Do you
// want parallel processing or no?
- (void) serial
{
  // Do everything on the main thread. So only deal with A.
  for( int i = 0 ; i < pcVertsA.size() ; i++ )
  {
    pcVertsA[i].pos = rot * pcVertsA[i].pos ;
  }
  [self prerender:context];
  drawPC( pcVertsA, GL_LINES ) ; // RENDER
  [self flipBuffers] ;
}

// Process data for game objects in parallel, then BLOCK
// the main thread, and draw all in serial from the main thread
// If your app is heavy processing, light drawing, use this mode.
- (void) parallelProcessSerialDraw
{
  /// Use the threadPool.
  [self prerender:context] ;
  
  // This MUST happen on the main thread before any drawing occurs.
  // It's short and fast, so I do it here,
  // before even creating any workorders.
  
  // Add a few workorders.  ORDER OF CREATION MATTERS, here
  // the AI workorder WILL RUN BEFORE the graphics workorder.
  WorkOrder *wo = new WorkOrder( "vertex transforms" ) ;
  
  // Cut into jobs of size.  Every vertex must be processed.
  int JOBSIZE = pcVertsA.size() / 4 ;
  
  for( int i = 0 ; i < pcVertsA.size() ; i+=JOBSIZE )
  {
    int startVert=i, endVert=i+JOBSIZE ;
    
    // If the end ends up OOB, clamp it.
    if( endVert > pcVertsA.size() )  endVert=pcVertsA.size() ;
    
    wo->addJob( new Callback0( [self,startVert,endVert](){ 
      // Your job is to process # verts
      for( int j = startVert ; j < endVert ; j++ )
      {
        // This is the same code as st
        pcVertsA[j].pos = rot * pcVertsA[j].pos ;
      }
    } ) ) ;
  }
  
  wo->finishedSubmission() ;
  threadPool->addWorkOrder( wo ) ;
  
  // The rendering is forced to go AFTER the ai comps, and the rendering
  // is also forced to run on the main thread.
  threadPool->wakeAll() ;
  
  // The main thread should be made to run worker jobs too.
  threadPool->runJobs() ;
  
  // If I finished first, wait until the worker thread is complete
  threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ;

  // SEQUENCE POINT 1: ALL VERTEX PROCESSING COMPLETE
  // --
  // A this point we have "merged" back onto the main thread.  All jobs are finished,
  // and all of the fish are sleeping again in the threadpool.
  //
  // I call this part a "sequence point".  In C a sequence point is
  // where "all side effects of previous instructions have been performed,
  // and no side effects from future evaluations have been performed."
  // In other words, ALL JOBS HAVE BEEN COMPLETED, THERE ARE NO CURRENTLY RUNNING JOBS,
  // AND IF YOU WAIT HERE FOREVER NOTHING WILL CHANGE ABOUT THE STATE OF THE PROGRAM.
  // 
  // This is a good point to go forward with rendering then, because all the computations
  // that move the vertices around etc, have been completed.
  //
  
  // SEQUENCE POINT 2: ALL RENDERING COMPLETE
  drawPC( pcVertsA, GL_LINES ) ;
  [self flipBuffers] ;
}

// in this mode, we process IN PARALLEL with draw.
// If your app is about 50-50 on the process/draw,
// use this mode.
- (void) parallelProcessAndDraw
{
  /// Use the threadPool.
  [self prerender:context] ;
  
  // We want to process data AND render data __at the same time__.
  // Because you can't render data you're currently touching, I
  // replicate the data 2x.  Each frame, processing happens on the *process array.
  // Drawing happens from the *draw array, which are the results of last frame's *process.
  // We alternate between A & B.
  if( draw == &pcVertsA )  process=&pcVertsA, draw=&pcVertsB ;  // Processing on A, drawing on B
  else  process=&pcVertsB, draw=&pcVertsA ;
  
  WorkOrder *wo = new WorkOrder( "vertex transforms" ) ;
  
  // PROCESS //
  // Cut into jobs of size.  Every vertex must be processed.
  int JOBSIZE = process->size() / 4 ;
  
  for( int i = 0 ; i < process->size() ; i+=JOBSIZE )
  {
    int startVert=i, endVert=i+JOBSIZE ;
    
    // If the end ends up OOB, clamp it.
    if( endVert > process->size() )  endVert=process->size() ;
    
    wo->addJob( new Callback0( [self,startVert,endVert](){ 
      // Your job is to process # verts
      for( int j = startVert ; j < endVert ; j++ )
      {
        // This is the same code as above
        (*process)[j].pos = rot * (*process)[j].pos ;
      }
    } ) ) ;
  }
  
  wo->finishedSubmission() ;
  threadPool->addWorkOrder( wo ) ;
  
  // The rendering is forced to go AFTER the ai comps, and the rendering
  // is also forced to run on the main thread.
  threadPool->wakeAll() ;
  
  // THIS IS THE DIFFERENCE BETWEEN parallelProcessSerialDraw and
  // parallelProcessAndDraw.  PROCESSING JUST STARTED, but we're going to
  // draw the results of processing of the PREVIOUS frame now.
  /////////threadPool->runJobs() ; // main thread doesn't participate in work
  /////////threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ; // doesn't block either

  // Instead draws immediately the results of last frame,
  drawPC( *draw, GL_LINES ) ;
  [self flipBuffers] ;
}

// Consider this 1 step of the game loop.
- (void) runFrame
{
  if( !threadingOn )
  {
    [self serial];
  }
  else
  {
    //[self parallelProcessSerialDraw];  // process in parallel, then block mainthread. mainthread draws frame results in serial.
    [self parallelProcessAndDraw];  // process IN PARALLEL with draw.
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
