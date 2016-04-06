#import "ThreadPool.h"
#import "ES1Renderer.h"

ThreadPool *threadPool = 0 ;

int Thread::NextThreadId=1 ;
int WorkOrder::NextWorkOrderId = 1 ;

int getNumberOfCores()
{
  host_basic_info_data_t hostInfo;
  mach_msg_type_number_t infoCount;

  infoCount = HOST_BASIC_INFO_COUNT;
  host_info( mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount ) ;
  
  return hostInfo.max_cpus ;
}

// The fishTank is where threads spin round and round
// when there's nothing to do, they sleep.
//
// This is where newly spawned threads LIVE.
// formerly called threadIdle
// <# #> <#fishtank#> <# #>
void* fishTank( void* execData )
{
  // Here's the smart bit:  the threads swimming around in the fish tank need to know who they are.
  Thread *thread = (Thread*)execData ;  // I pick up the thread object THAT SPAWNED this execution thread.
  // The Thread object is actually created on the main thread (in the beginning the main thread is the only one in existence to be
  // able to actually create the worker threads!)
  
  // Bind my context to me
  if( thread->glContext != nil )
  {
    if( ![EAGLContext setCurrentContext:thread->glContext] )
      puts( "ERROR: Worker thread could not setCurrentContext." ) ;
      
    //glBindFramebufferOES( GL_FRAMEBUFFER_OES, thread->defaultFramebuffer ) ;
		//glBindRenderbufferOES( GL_RENDERBUFFER_OES, thread->colorRenderbuffer ) ;
		//glFramebufferRenderbufferOES( GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, thread->colorRenderbuffer ) ;
    
  }
  
  ++threadPool->numThreadsSwimming ; // a fish is born. fishes++.
  
  while( !thread->exiting ) {

    // Try and find a job.
    Callback* job = threadPool->getNextJob() ; // THIS LINE MEANS THE SUPERGLOBAL threadPool MUST BE
    // CREATED ALREADY BEFORE YOU SPAWN A THREAD.
    
    // If you got a job, execute it then delete it.
    if( job ) {
      //printf( "Thread %d is executing a job\n", thread->num ) ;
      job->exec() ;
      delete job ;
    }
    else {
      // NOJOBS.
      
      ///printf( "Thread %d going to sleep with the fishes (in the fishtank)\n", thread->num ) ;
      if( ! --threadPool->numThreadsSwimming ) // this little fishy went to sleep.
      {
        // Ok.  There are NOJOBS since we couldn't pull a job from the queue (it was empty).
        // If I am THE LAST FISH GOING TO SLEEP, I turn out all the lights etc (I call noJobs()).
        // Calling noJobs() has the effect of waking the main thread if it was asleep.
        // If there are NOJOBS NOW before you go to sleep
        threadPool->noJobs() ;
      }
      
      thread->sleep() ; // If you couldn't find a job, sleep.  You will be awoken as soon as
      // a new job is added.  You might not GET the job, but you'll be awoken.
      ++threadPool->numThreadsSwimming ; // as soon as the fishy awakes, he's swimming again.
    }
    
    // So if you got a job, you continue exeution and get another one.
    // If you DIDN'T find a job, you slept and would only pick up here
    // when another thread awakens you (any other thread that adds a job to threadPool woudl awaken you.).
    
    // If you were awoken and you should exit, you WILL NOT repeat the loop (so you won't try to getNextJob again).
  }
  
  --threadPool->numThreadsSwimming ; // a fish dies. one less fish in the tank.
  
  // The thread is going to exit.  So delete the Thread object here.  It doesn't get deleted in ThreadPool.
  delete thread ;
  
  // In the thread idle, 
  // 1) Check for jobs.
  // 2) Run the jobs.
  return 0 ;
}

@implementation EmptyObject
- ( void )empty{}
@end

// Add an entire workorder to the q
WorkOrder* ThreadPool::startWorkOrder( WorkOrder* wo ) {
  wo->finishedSubmission() ; // I mark it as finished submission now, because we're going to start working on it.
  // You can't add tasks once we start working on the order.
  
  LOCKQUEUES ;
  workOrders.push_back( wo ) ;
  UNLOCKQUEUES ;
  
  threadPool->wakeAll() ; // TELL EVERYBODY A WORKORDER HAS BEEN ADDED!
  return wo ;
}




void testBackgroundWork()
{
  // Add a few workorders.
  WorkOrder *aiWo = new WorkOrder( "AI" ) ;
  WorkOrder *graphicsWo = new WorkOrder( "graphics" ) ;
  
  // Just create a big bunch of like fake jobs
  // All 100 of the jobs added to each WorkOrder ARE parallelizable,
  // but the graphics jobs will run AFTER the ai jobs.
  for( int i = 0 ; i < 10 ; i++ )
  {
    aiWo->addJob( new Callback0( [](){ 
      // This is the code of the job.
      long long sum = 0 ;
      for( int j = 0 ; j < 100000000L ; j++ )
        sum += rand() ;
      printf( "AI: The sum was %lld\n", sum ) ;
    } ) ) ;
    
    graphicsWo->addJob( new Callback0( [](){
      long long sum = 0 ;
      for( int j = 0 ; j < 200000000L ; j++ )
        sum += rand() ;
      printf( "Graphics job: got %lld\n", sum ) ; // this makes no sense, its just code that runs.
    } ) ) ;
  }

  // ORDER OF ADDITION MATTERS, here
  // the AI workorder WILL RUN IN TOTALITY
  // (with its individual Jobs allowed to be executed in parallel)
  // BEFORE the graphics workorder ever starts
  threadPool->startWorkOrder( aiWo ) ;
  threadPool->startWorkOrder( graphicsWo ) ;
  
  threadPool->printAll() ;
}









