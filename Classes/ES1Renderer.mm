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


// #verts to process
#define NUMVERTS 40000
enum ParallelTechnique
{
  // Serial processing is the default (not multithreaded)
  SerialProcessThenDraw,
  
  // process in parallel, then block mainthread. mainthread draws frame results in serial.
  ParallelProcessThenSerialDraw,
  
  // Good, but no need to use since `parallelProcessSerialDraw` seems to perform equally well.
  // Since you always draw the LAST FRAME computed, it means input will lag one additional frame
  // (effectively giving you 30fps response rates for a 60 fps display rate). Not recommended.
  ParallelProcessAndDrawTogether
} ;

int parallelTechnique = ParallelProcessThenSerialDraw ;

static Matrix3f rot = Matrix3f::rotation( Vector3f::random(), 0.01f ) ;
static Matrix3f rot2 = Matrix3f::rotation( Vector3f::random(), 0.01f ) ;
static Matrix3f rot3 = Matrix3f::rotation( Vector3f::random(), 0.01f ) ;

// Often src and dst are the same, except for parallelProcessAndDraw.
void processVertices( vector<VertexPC>* dst, vector<VertexPC>* src, int startVertex, int endVertex )
{
  // to increase the weight of processing, add more computations here.
  for( int i = startVertex ; i < endVertex ; i++ )
  {
    (*dst)[i].pos = rot * (*src)[i].pos ;
    (*dst)[i].pos = rot2 * (*src)[i].pos ;
    (*dst)[i].pos = rot3 * (*src)[i].pos ;
  }
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
  
  // Gen data, #verts
  for( int i = 0 ; i < NUMVERTS ; i++ )
  {
    Vector3f p = Vector3f::random(-1.f,1.f) ;
    Vector3f dir = Vector3f::random(-1.f,1.f).normalize() ;
    
    addLine( pcVertsA, p, p+dir*0.05f, Vector4f::random() ) ;
  }
  pcVertsB=pcVertsA;//copy it
  
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

// Process first, draw afterward.  This is just normal
// serial processing that most apps use.
- (void) serial
{
  // Do everything on the main thread. So only deal with A.
  
  // Process all vertices
  processVertices( &pcVertsA, &pcVertsA, 0, (int)pcVertsA.size() ) ;
  
  // Draw.
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
  // This MUST happen on the main thread before any drawing occurs.
  // It's short and fast, so I do it here,
  // before even creating any workorders.
  [self prerender:context] ;
    
  // Add a few workorders.
  WorkOrder *wo = new WorkOrder( "vertex transforms" ) ;
  
  // Cut into jobs of size.  Every vertex must be processed.
  int JOBSIZE = (int)pcVertsA.size() / 4 ;
  
  for( int i = 0 ; i < pcVertsA.size() ; i+=JOBSIZE )
  {
    int startVert=i, endVert=i+JOBSIZE ;
    if( endVert > (int)pcVertsA.size() )  endVert=(int)pcVertsA.size() ;  // If the end ends up OOB, clamp it.
    
    // Add a callback object to run processVertices from startVert to endVert.
    wo->addJob( new Callback4<vector<VertexPC>*, vector<VertexPC>*, int, int>
      ( processVertices, &pcVertsA, &pcVertsA, startVert, endVert ) ) ;
  }
  
  threadPool->startWorkOrder( wo ) ; // worker threads start crunching away
  
  // The main thread should be made to run worker jobs too.
  threadPool->runJobs() ;
  
  // If the main thread finished first, it wait >HERE< until the worker thread is completed
  // what it is working on.  This establishes a "sequence point": after the next line of code,
  // all worker jobs will be done and the worker thread will already be sleeping.
  threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ;

  // SEQUENCE POINT: ALL VERTEX PROCESSING COMPLETE
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
  // Draw on the main thread
  drawPC( pcVertsA, GL_LINES ) ;
  [self flipBuffers] ;
}

// in this mode, we process IN PARALLEL with draw.
// If your app is about 50-50 on the process/draw,
// use this mode.
- (void) parallelProcessAndDrawLagged1Frame
{
  [self prerender:context] ;
  
  // `draw` is where things __are__.  `process` is where they __will be__ next frame.
  // input affects `process`, which means you don't get to see the results of your input
  // that same frame you inputted it.  Instead, you will see it 1 frame later, when `process`
  // becomes the new `draw`.
  // `draw` is read from by both threads.  `process` is written to.
  
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
  int JOBSIZE = (int)draw->size() / 4 ;
  
  for( int i = 0 ; i < draw->size() ; i+=JOBSIZE )
  {
    int startVert=i, endVert=i+JOBSIZE ;
    
    // If the end ends up OOB, clamp it.
    if( endVert > (int)draw->size() )  endVert=(int)draw->size() ;
    
    // next state (`process`) is from the current state (`draw`)
    // This is different from usual processing used in the other examples.
    wo->addJob( new Callback4<vector<VertexPC>*, vector<VertexPC>*, int, int>
      ( processVertices, process, draw, startVert, endVert ) ) ;
  }
  
  threadPool->startWorkOrder( wo ) ;
  
  // THIS IS THE DIFFERENCE BETWEEN parallelProcessSerialDraw and
  // parallelProcessAndDraw.  PROCESSING JUST STARTED with the startWorkOrder call above, but we're going to
  // draw the results of processing of the PREVIOUS frame now.
  /////////threadPool->runJobs() ; // main thread doesn't participate in work
  /////////threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ; // doesn't block either

  // Instead draws immediately the results of last frame,
  drawPC( *draw, GL_LINES ) ;
  
  // Ok, if we get into DRAWING of the next frame BEFORE processing of the previous frame finished,
  // it means that the game is process-heavy (so like 70% processing, 30% drawing), so you might
  // want to consider a parallelProcessSerialDraw scheme.
  threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ; // WAIT. before processing the next frame,
  // it is possible that the last frame isn't finished processing yet.
  
  [self flipBuffers] ;
}

// THIS DOESN'T ACTUALLY WORK AS EXPECTED.  THE REASON IS
// YOU CAN'T RENDER FROM TWO SEPARATE CONTEXTS TO THE SAME
// FRAMEBUFFER SIMULTANEOUSLY.  This is only here to remember
// that this way is invalid.
- (void) parallelProcessAndDrawSameFrame // WRONG
{
  [self prerender:context] ;
  
  WorkOrder *wo = new WorkOrder( "vertex transforms" ) ;
  int JOBSIZE = (int)pcVertsA.size() / 4 ;
  for( int i = 0 ; i < pcVertsA.size() ; i+=JOBSIZE )
  {
    int startVert=i, endVert=i+JOBSIZE ;
    if( endVert > (int)pcVertsA.size() )  endVert=(int)pcVertsA.size() ;
    
    wo->addJob( new Callback4<vector<VertexPC>*, vector<VertexPC>*, int, int>
      ( processVertices, &pcVertsA, &pcVertsA, startVert, endVert ) ) ;
  }
  
  threadPool->startWorkOrder( wo ) ;
  threadPool->sequencePoint( 0 ) ;
  
  // SEQUENCE POINT 1: ALL VERTEX PROCESSING COMPLETE
  
  #if 1
  puts( "ERROR: THIS WAY DOESN'T WORK" ) ;
  // Break up vertex submission calls across threads.
  // THIS DOESN'T WORK BECAUSE DRAW CALLS TOUCH THE FRAMEBUFFER,
  // AND YOU CAN'T TOUCH THE SAME GL OBJECT FROM DIFFERENT THREADS,
  // ALBEIT FROM SEPARATE CONTEXTS.
  // The results are "unpredictable". On my iPad, it's just very "blinky".
  wo = new WorkOrder( "rendering" ) ; // WRONG
  for( int i = 0 ; i < pcVertsA.size() ; i+=JOBSIZE ) // WRONG
  {
    int startVert=i, numVerts=JOBSIZE ;
    if( i+JOBSIZE > (int)pcVertsA.size() )  JOBSIZE=(int)pcVertsA.size()-i ;  // last job may be smaller
    wo->addJob( new Callback0( [self,startVert,numVerts](){ 
      [self setupTransformations];
      drawPC( pcVertsA, startVert, numVerts, GL_LINES ) ; // WRONG // WRONG // WRONG // WRONG
      //glFlush() ;
    } ) ) ;
  }
  threadPool->startWorkOrder( wo ) ;
  
  #else
  // Checking that above loop is actually correct (it is), but dispatching on main thread
  // so the render actually works
  for( int i = 0 ; i < pcVertsA.size() ; i+=JOBSIZE )
  {
    int startVert=i, numVerts=JOBSIZE ;
    if( i+JOBSIZE > pcVertsA.size() )  JOBSIZE=pcVertsA.size()-i ;
    [self setupTransformations] ;
    drawPC( pcVertsA, startVert, numVerts, GL_LINES ) ;
  }
  #endif
  
  threadPool->mainThreadBlockUntilAllJobsFinished( 0 ) ;
  // SEQUENCE POINT 2: ALL RENDERING COMPLETE
  
  [self flipBuffers] ;
}



// Consider this 1 step of the game loop.
- (void) runFrame
{
  switch( parallelTechnique )
  {
  case SerialProcessThenDraw:
    // Serial processing is the default (not multithreaded)
    [self serial]; // see how much worse processing would be if you weren't using threading at all.
    break ;
    
  case ParallelProcessThenSerialDraw:
    // Seems to be best. 
    [self parallelProcessSerialDraw];  // BEST. process in parallel, then block mainthread. mainthread draws frame results in serial.
    break ;
    
  case ParallelProcessAndDrawTogether:
    // Good, but no need to use since `parallelProcessSerialDraw` seems to perform equally well
    [self parallelProcessAndDrawLagged1Frame];  // OK. process IN PARALLEL with draw.
    break;

  default:
    puts( "ERROR: INVALID PARALLELTECHNIQUE" ) ;
    break;
  }

  // parallelProcessAndDrawSameFrame: This technique doesn't work.
  //[self parallelProcessAndDrawSameFrame];  // X doesn't work

  // parallelProcessAndDraw is supposed to extract the most from the device, because it
  // has both threads running in parallel all the time.  The main thread only blocks
  // if it runs _faster_ than the worker thread.
  // In my experiments, I kind of find that it works ok, but `parallelProcessSerialDraw`
  // is pretty much equivalent for heavy CPU processing and large buffer flushing.
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
