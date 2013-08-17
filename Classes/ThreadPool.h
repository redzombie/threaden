#ifndef THREADPOOL_H
#define THREADPOOL_H

/*

  https://github.com/redzombie/threaden
  Theaden - simple iOS threading
  version 1.0.0, Aug 15 2013 859p

  Copyright (C) 2013 Red Zombie, William Sherif

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  William Sherif
  will.sherif@gmail.com

*/

#import <OpenGLES/EAGL.h>
#import "Callback.h"

#include <mach/mach_host.h> // for counting cores
#include <pthread.h>

#include <string>
#include <vector>
#include <deque>
using namespace std ;

struct Lock
{
  pthread_mutex_t *lock ;
  Lock( pthread_mutex_t * iLock ){
    lock = iLock ;
    pthread_mutex_lock( lock ) ;
  }
  ~Lock(){
    pthread_mutex_unlock( lock ) ;
  }
} ;

// An integer counter primitive that provides LOCKING
// increment and decrement operations
struct LockCounter
{
private:
  int num ;
  pthread_mutex_t mutex ;

public:
  LockCounter() : num(0) {
    pthread_mutex_init( &mutex, 0 ) ;
  }
  int read() { // aka getValue
    Lock numLock( &mutex ) ;
    return num ;
  }
  int write( int val ) { // aka setValue
    Lock numLock( &mutex ) ;
    return num=val ;
  }
  // Preincrement.
  int operator++() {
    Lock numLock( &mutex ) ;
    return ++num ;
  }
  // Predecrement.
  int operator--() {
    Lock numLock( &mutex ) ;
    return --num ;
  }
  // Postincrement
  int operator++( int ) {
    Lock numLock( &mutex ) ;
    return num++ ;
  }
  // Postdecrement
  int operator--( int ) {
    Lock numLock( &mutex ) ;
    return num-- ;
  }
} ;

int getNumberOfCores() ;

// This is where newly spawned threads LIVE.
// could call this fishTank or whatever.  Its where threads
// spin around.
void* fishTank( void* execData ) ;

// A THREAD:  Something that runs code.
struct Thread
{
  // EAGL Shared Context:
  // http://gamedev.stackexchange.com/questions/53382/displaying-animations-during-loading-screens/53386#53386
  
  // An EAGL Sharegroup Manages OpenGL ES Objects for the Context:
  // http://developer.apple.com/library/ios/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/WorkingwithOpenGLESContexts/WorkingwithOpenGLESContexts.html#//apple_ref/doc/uid/TP40008793-CH2-SW5
  
  // Concurrency and OpenGL ES:
  // http://developer.apple.com/library/ios/documentation/3ddrawing/conceptual/opengles_programmingguide/ConcurrencyandOpenGLES/ConcurrencyandOpenGLES.html
  
  // Here I have an EAGLContext for the thread. If the separate thread wants to use OpenGL commands,
  // it _can_, but under some restrictions.
  // YOU COULD use a single context for the entire app, but you would have to LOCK access to OpenGL
  // commands.
  //   > "If for some reason you decide to set more than one thread to target the same context, 
  //      then you must synchronize threads by placing a mutex around all OpenGL ES calls to the context."
  // So we avoid doing that here.  We always make a 2nd context that shares the data of the 1st context.
  // For the 2 contexts to share the data without clobbering each other, they must obey the following rules:
  
  // It is your application’s responsibility to manage state changes to OpenGL ES objects when the sharegroup is shared by multiple contexts.
  // Here are the rules:
  // 
  // 1. Your application may access the object across multiple contexts simultaneously
  //    __provided the object is not being modified__.
  // 2. _While the object is being modified_ by commands sent to a context,
  //    __the object must not be read or modified on any other context__.
  // 3. After an object has been modified, all contexts must rebind the object to see the changes.
  //    The contents of the object are undefined if a context references it before binding it.
  EAGLContext *glContext ;
  GLuint defaultFramebuffer, colorRenderbuffer ;
  
  static int NextThreadId ;
  
  string name ; // any special name
  volatile int num ; // just the manual tracker # for which thread it is.
  // Don't confuse this with the `pthread_t` threadId.
  
  // a pthread_t is a _opaque_pthread_t* pointer, so it really is just a memory address.
  pthread_t threadId ;
  pthread_mutex_t suspendMutex ;
  pthread_cond_t resumeCondition ;
  
  volatile bool suspended, exiting ;

private:
  void init()
  {
    suspended=exiting=0;
    num = NextThreadId++ ;
    char b[255];  sprintf( b, "thread %d", num ) ;
    name = b ;
    glContext = nil ;
    pthread_mutex_init( &suspendMutex, 0 ) ;
    pthread_cond_init( &resumeCondition, 0 ) ;
  }
  
  void makeThread()
  {
    // What this does is, give THIS object's threadId a value.  THEN it SPINS OFF a new thread,
    // with the pthread_create call.  So from the pthread_create() call, THERE ARE 2 THREADS OF EXECUTION.
    // My only way to CONTROL the other thread of execution is to tell it, VIA system calls BY ITS THREAD ID
    //pthread_create( pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *), void *arg ) ;
    //pthread_create_suspended_np(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *);
    pthread_create( &threadId, NULL, fishTank, this ) ; // --new thread-->  to the fishTank
    
    // NSThread ref: http://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/Foundation/Classes/NSThread_Class/Reference/Reference.html
    printf( "Thread %d created new thread at memory address %d\n", (int)pthread_self(), (int)threadId ) ;
    //   |
    //   | calling thread
    //   v
    // (Exits this routine, returns to whatever it was doing)
  }
  
public:  
  // Thread doesn't use opengl. my programmer, my programmer, don't lie to me.
  Thread()
  {
    init() ;
    makeThread() ;
  }
  
  // used for creating the object REPRESENTING the main thread
  // (it doesn't make the thread it just makes a Thread object surrounding it)
  Thread( const pthread_t &iThreadId ) {
    if( ![NSThread isMainThread] ) {
      puts( "ERROR: This Thread ctor intended for use by main thread only" ) ;
      return ;
    }
    
    init() ;
    threadId = iThreadId ;
    name="MAIN THREAD" ;
  }
  
  Thread( const string& iname )
  {
    init() ;
    name=iname ;
    makeThread() ;
  }

  // thread WILL use opengl  
  Thread( EAGLContext *mainContext, GLuint iDefaultFramebuffer, GLuint iColorRenderbuffer )
  {
    init() ;
    // The name gets overwritten to "OpenGL thread 2" or whatever
    char b[255];  sprintf( b, "OpenGL thread %d", num ) ;
    name = b ;
    
    // Make a glContext for this thread that shares resources with the mainContext.
    glContext = [[EAGLContext alloc] initWithAPI:[mainContext API] sharegroup:[mainContext sharegroup]];
    defaultFramebuffer = iDefaultFramebuffer ;
    colorRenderbuffer = iColorRenderbuffer ;
    
    // Boot the thread with the eaglcontext.
    pthread_create( &threadId, NULL, fishTank, this ) ;  
  }
  
  ~Thread()
  {
    //pthread_exit( threadId ) ; // you could use this.  But I'm letting the thread exit fishTank itself.
    // THIS ONLY GETS INVOKED WHEN THE THREAD IS EXITING ITS fishTank.
    
    printf( "Thread %d is being destroyed\n", num ) ;
    pthread_mutex_destroy( &suspendMutex ) ;
    pthread_cond_destroy( &resumeCondition ) ;
  }
  
  bool isSleeping() {
    Lock suspendLock( &suspendMutex ) ;
    return suspended ;
  }
  
  /// CALLER IS PUT TO SLEEP
  void sleep()
  {
    // This isn't as simple as you would wish, the while loop is
    // needed due to the possibility of "spurious wakeups".
    // See http://stackoverflow.com/a/3141224/
    pthread_mutex_lock( &suspendMutex ) ;
    if( suspended ) {
      printf( "Thread %d: I'm trying to sleep even though I'm already sleeping. "
              "This means an impossible bug has occurred.\n", num ) ;
      pthread_mutex_unlock( &suspendMutex ) ;
      return ;
    }
    suspended = 1 ;
    
    // The below loop is because `pthread_cond_wait` is like a loose chain
    // that COULD break at any moment.  But we don't want to let the dogs out
    // until SOMEBODY calls wakeup() (which sets suspended=0).
    while( suspended )  // If the pitbull somehow breaks out, put him back in his cage
    // pthread_cond_wait:  atomically releases mutex and cause the calling thread to block on the condition variable cond
      pthread_cond_wait( &resumeCondition, &suspendMutex ) ;  // put him back in his cage.
    
    pthread_mutex_unlock( &suspendMutex ) ;
  }
  
  // You obv need to call this from another thread
  void wakeup()
  {
    pthread_mutex_lock( &suspendMutex ) ;
    
    if( !suspended ) {
      // I'm not sleeping, no need to wake me.
      printf( "Thread %d: I'm already awake.\n", num ) ;
      pthread_mutex_unlock( &suspendMutex ) ;
      return ;
    }
    
    suspended = 0 ;
    pthread_cond_signal( &resumeCondition ) ;  // send the wakeup signal
    pthread_mutex_unlock( &suspendMutex ) ;
  }
} ;

// A WorkOrder consists of a bunch of jobs that can be run in //l.
struct WorkOrder //ParallelizableBatch // I hate that name
{
  int workOrderId ;
  string name ;
  deque<Callback*> jobs ; // These are the individual jobs that make up the work order.
  // A flag that stops this WorkOrder from being deleted, even if it becomes EMPTY of jobs.
  bool stillAdding ;
  pthread_mutex_t mutexJob, mutexStillAdding ;
  static int NextWorkOrderId ;
  
private:
  // Copying WorkOrders forbidden
  WorkOrder( const WorkOrder& wo ) {
    puts( "ERROR: Copying WorkOrders should not be done!" ) ;
  }

public:
  WorkOrder( const string& iname ) {
    pthread_mutex_init( &mutexJob, 0 ) ;
    name=iname ;
    workOrderId = NextWorkOrderId++ ;
    stillAdding = 1 ;
    //printf( "WorkOrder `%s`, id=%d created\n", name.c_str(), workOrderId ) ;
  }
  
  ~WorkOrder()
  {
    pthread_mutex_lock( &mutexJob ) ;
    
    if( jobs.size() )
    {
      printf( "WARNING: WorkOrder `%s` being destroyed while it still has %d jobs in queue\n",
        name.c_str(), (int)jobs.size() ) ;
      // destroy those remaining callbacks.
      for( deque<Callback*>::iterator iter=jobs.begin() ; iter!=jobs.end() ; ++iter )
        delete *iter ;
    }
    
    pthread_mutex_unlock( &mutexJob ) ;
    pthread_mutex_destroy( &mutexJob ) ;
  }
  
  Callback* getNextJob() {
    pthread_mutex_lock( &mutexJob ) ;
    
    if( !jobs.size() ) {
      pthread_mutex_unlock( &mutexJob ) ;
      return 0 ;
    }
    
    Callback* j = jobs.front() ;
    jobs.pop_front() ; // YOU TOOK IT
    
    pthread_mutex_unlock( &mutexJob ) ;
    
    return j ;
  } //lock released as soon as you get out
  
  WorkOrder* addJob( Callback* newJob ) ;
  
  // Adds the job without waking anybody up
  WorkOrder* addJobQuietly( Callback* newJob )
  {
    pthread_mutex_lock( &mutexJob ) ;
    jobs.push_back( newJob ) ;
    pthread_mutex_unlock( &mutexJob ) ;
    return this ;
  }
  
  // You finished submitting jobs and want this object to be destroyed
  // by the thread that finishes the last job in the list (ie you are NOT
  // adding to this list anymore). Also starts the threadPool worker thread.
  void finishedSubmission() ;
  
  // I tell you if this list is marked for still adding (undeletable) or not
  bool isStillAdding()
  {
    Lock lockSA( &mutexStillAdding ) ;
    return stillAdding ;
  }
  
  // Just runs all the jobs in the queue ON THE CALLING THREAD.  used when you want
  // an entire workorder to be processed by one thread.
  // used mainly for jobs that must be run by ONLY the mainthread in a special queue,
  // OR can be used for functional decomposition style programming.
  void runAll()
  {
    pthread_mutex_lock( &mutexJob ) ;
    for( Callback* job : jobs ) {
      job->exec() ;
      delete job ;
    }
    jobs.clear() ;
    pthread_mutex_unlock( &mutexJob ) ;
  }
  
  void print() const {
    printf( "  - WorkOrder `%s`, id=%d has %lu jobs\n", name.c_str(), workOrderId, jobs.size() ) ;
  }
} ;

// ThreadPool:  Manages all the threads, dispatches jobs,
struct ThreadPool
{
private:
  int nCores ;
  
  Thread* mainThread ;
  vector<Thread*> threads ;

public:
  LockCounter numThreadsSwimming ;  // # threads that are currently swimming (not sleeping) in the fishTank.

private:  
  //Thread* threadPoolThread ; // This is the THREADPOOL'S THREAD.  It continually runs and suspends itself
  // when all jobs are done.  Calling any of the addJob functions 
  // wakes this thread up.  (actually didn't need it)
  
  // so you don't r/w the workOrders deque at the same time (mainthread writes, worker threads read)
  pthread_mutex_t mutexWorkOrders ;
  
  // Anybody who TOUCHES workOrders MUST LOCK IT.
  #define LOCKQUEUES pthread_mutex_lock( &mutexWorkOrders )
  #define UNLOCKQUEUES pthread_mutex_unlock( &mutexWorkOrders )
  
  // The jobs list contains LISTS OF JOBS that
  // must be run in order.
  // So we have a LIST OF LISTS of Callback*.
  // each LIST of Callback* can be executed in parallel, (on the many different threads)
  // while the Parallelizable
  // So you only need 2 levels of organization here.
  //  - (deque) of jobs that CAN BE run in parallel
  //    - it's a deque because you push new jobs in the back but pull from the front.
  //    - i hate the queue class and never use it because it is just actually a crippled version of deque (it is an "adaptor")
  //  - (deque) of (deque of jobs) that need to be run in order.  actually you should not pop from the back, but I am still using deque.
  deque<  WorkOrder*  > workOrders ;
  
  WorkOrder* workOrderForMainThread ;
  
  // The current workOrder being processed.
  //WorkOrder* currentWorkOrder ;

  // Copying ThreadPools forbidden
  ThreadPool( const ThreadPool& wo ) {
    puts( "ERROR: Copying ThreadPools should not be done!" ) ;
  }
  
public:
  ThreadPool() {
    init() ;
  }
  
  ~ThreadPool() {
    // kill all threads.
    /// You could do it this way.  OR you could set exiting=1, so you don't crash a still running thread.
    //for( Thread* thread : threads )
    //  delete thread ;

    for( Thread* thread : threads ) {
      thread->exiting = 1 ;
      thread->wakeup() ; // make sure its awake, so it can exit.
    }
    
    free( mainThread ) ;

    pthread_mutex_destroy( &mutexWorkOrders ) ;
  }
  
  inline int getNumCores() const { return nCores ; }
  
private:
  // Reads # cores, and ensures app is MT
  void init()
  {
    pthread_mutex_init( &mutexWorkOrders, 0 ) ;
    
    // create nCores-1 threads
    nCores = getNumberOfCores() ;
    
    // Create the work order for the main thread
    workOrderForMainThread = new WorkOrder( "WorkOrders for Main Thread" ) ;
    
    // I need to circumvent the def ctor, becausee I don't want an actual thread to be created,
    // one already exists.
    mainThread = new Thread( pthread_self() ) ;
    
    // IF THE APP IS NOT ALREADY CONSIDERED MULTITHREADED, IT'S EXTREMELY IMPORTANT YOU MAKE IT SO
    // SINCE WE'RE USING POSIX THREADS HERE
    // See http://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/Foundation/Classes/NSThread_Class/Reference/Reference.html#//apple_ref/occ/clm/NSThread/isMultiThreaded
    if( ![NSThread isMultiThreaded] ) 
    {
      puts( "App not already mt, making mt" ) ;
      [NSThread detachNewThreadSelector:nil toTarget:nil withObject:nil] ;
    } 
    if( ![NSThread isMultiThreaded] ) 
      puts( "ERROR: App STILL not mt" ) ;
  }

public:
  // YOU CANNOT CALL THIS BEFORE THE SUPERGLOBAL `threadPool` IS CREATED
  // BECAUSE 
  void createWorkerThreads( int numThreads ) {
    printf( "ThreadPool: Creating %d threads\n", numThreads ) ;
    for( int i = 0 ; i < numThreads ; i++ )
      threads.push_back( new Thread() ) ; // These will sleep as soon as they boot as they will find no jobs to do
  }
  
  // You want to create worker threads with their own OpenGL context.
  void createWorkerThreads( int numThreads, EAGLContext* glContext, GLuint iDefaultFramebuffer, GLuint iColorRenderbuffer ) {
    mainThread->glContext = glContext ;
    printf( "ThreadPool: Creating %d threads with their own OpenGL contexts\n", numThreads ) ;
    for( int i = 0 ; i < numThreads ; i++ )
      threads.push_back( new Thread( glContext, iDefaultFramebuffer, iColorRenderbuffer ) ) ;
  }

  // A thread asks to retrieve a pointer to itself
  Thread* getMe() {
    pthread_t selfId = pthread_self() ;
    
    // ru main?
    if( mainThread->threadId == selfId )
      return mainThread ;
    
    for( Thread* t : threads )
      if( t->threadId == selfId )
        return t ;
        
    puts( "ERROR: I couldn't find your Thread object." ) ;
    return 0 ;
  }

  // This adds a job to the "current workorder" in other words THE BACK DEQUE.
  WorkOrder* createNewWorkOrder( const string& name ) {
    WorkOrder *wo = new WorkOrder( name ) ;

    LOCKQUEUES ;
    workOrders.push_back( wo ) ;
    UNLOCKQUEUES ;

    return wo ;
  }//lock release

  WorkOrder* addJob( Callback* job ) {
    LOCKQUEUES ;
    WorkOrder *wo ;
    if( workOrders.size() )  wo = workOrders.back() ;
    else {
      wo = new WorkOrder( "__UNNAMED WORK ORDER__" ) ;
      workOrders.push_back( wo ) ;
    }
    UNLOCKQUEUES ;
    return wo->addJob( job ) ; // ADD IT TO THE BACK WORKORDER
  }//lock release

  // avoid this func, because it involves a search (if you just keep a reference to
  // the original workorder after creation, you won't need to deal with this searching business)
  WorkOrder* addJob( const string& toWorkOrder, Callback* job ) { 
    
    WorkOrder *wo ;
    
    //Lock woLock( &mutexWorkOrders ) ; // don't pee on me (don't sabotage the list while I am iterating on it.)
    // Me iterating over the list (reading) is just as sensitive as you pushing into its back.
    
    // Both readers AND writers of the list must lock it.  If two (blind) people
    // agree to knock before entering the bathroom and 1 always
    // knocks but 2 NEVER does, the deal is broken and 2 will end up
    // pissing all over 1 (or getting pee all over him).
    LOCKQUEUES ;
    for( WorkOrder* wo : workOrders )
      if( wo->name==toWorkOrder )
      {
        // AT THIS POINT, the woListLock could be released. you could not release here with the object/scope lock though.
        UNLOCKQUEUES ;
        return wo->addJob( job ) ;
      }
    
    // If you get here, the wo didn't exist, so create it.
    //return createNewWorkOrder( toWorkOrder )->addJob( job ) ; // DO NOT DOUBLE LOCK
    wo = new WorkOrder( toWorkOrder ) ;
    workOrders.push_back( wo ) ; // I will no longer touch workOrders.
    UNLOCKQUEUES ;
    printf( "Warning: workOrder name=`%s` didn't exist, but I created a new one for you\n", toWorkOrder.c_str() ) ;
    
    wo->addJob( job ) ;
    return wo ;
  }//lock release
  
  // Add an entire workorder to the q
  WorkOrder* addWorkOrder( WorkOrder* wo ) {
    //wo->finishedSubmission() ; // I mark it as finished submission now, because we're going to start working on it.
    // You can't add tasks once we start working on the order. WELL I DON'T ENFORCE THIS. If you want to leave a submitted
    // job as stillAdding, so be it.  I won't delete it, but you're responsible for your list getting crowded then.
    LOCKQUEUES ;
    workOrders.push_back( wo ) ;
    UNLOCKQUEUES ;
    return wo ;
  }
  
  //
  void printAll()
  {
    LOCKQUEUES ;
    printf( "ThreadPool has %lu work orders\n", workOrders.size() ) ;
    for( const WorkOrder* wo : workOrders )
      wo->print() ;
    UNLOCKQUEUES ;
  }
  
  void wakeAll() {
    // This triggers wakeup of all threads that are sleeping workorders.
    // This gets run EVERY TIME a job gets added.
    //puts( "Waking all" ) ;
    for( Thread* t : threads )
      if( t->isSleeping() )
        t->wakeup() ;
  }
  
  
  
  // You call all workers to go to sleep when there is absolutely no work left in the threadpool
  // This doesn't work, sleep must be called from the thread that is going to sleep.
  // Put another way, only you can make yourself fall asleep. No one can magically
  // put you to sleep without you doing it yourself.
  // void sleepAll() {
  //   for( Thread* t : threads )
  //     if( !t->suspended )
  //       t->sleep() ;
  // }

  // DOESN'T count the jobs for the main thread.
  // can be used to busy-wait the renderer until all worker threads
  // are done.
  bool hasJobs() {
    Lock woLock( &mutexWorkOrders ) ;
    return workOrders.size() ;
  }
  
  // This gets called when there are NO JOBS LEFT.
  void noJobs() {
    //puts( "No jobs left" ) ;
    if( mainThread->isSleeping() ) {
      //puts( "Waking up the main thread" ) ;
      mainThread->wakeup() ;
    }
  }
  
  // THREAD INTERFACE.  This is how you pull the next available job,
  // and effectively shut down the threadpool when there are none left :)
  // This function is an example of the 10,000 places where an UNLOCK
  // call can be missed (many return points).  In this function a
  // Lock object that autounlocks on destroy would help.
  Callback* getNextJob() {
  
    LOCKQUEUES ;
    if( !workOrders.size() ) {
      UNLOCKQUEUES ;
      
      //printf( "There are absolutely no jobs left to do.  You should sleep\n" ) ;
      ///noJobs() ; // Actually cannot conclude there are noJobs here. The last
      // thread that goes to sleep should say that.  If there is still a thread awake working,
      // then __that thread isn't done its job yet__ which means not all jobs have been complete.
      return 0 ;
    }
    
    // There's a workorder, 
    WorkOrder *wo = workOrders.front() ;
    
    // Try to get the next job.
    Callback *job = wo->getNextJob() ;
    if( job ) {
      UNLOCKQUEUES ; // RELEASE THE LOCK
      return job ; // you got one. thats all we need.
    }
    
    // here there was no job in the front list.
    // that means the front list is empty
    if( !wo->isStillAdding() ){
      delete wo ;  // Delete that ptr.
      // If the wo was stillAdding mode, then you
      // do not pop it or anything.  You just leave it there.
      // This can deadlock processing if its on stillAddingMode
      // but the person completely forgot to push in new jobs or call finishedSubmission.
      workOrders.pop_front() ; // pop the front list, because its empty
    }
    //else puts( "WorkOrder stillAdding, not deleting" ) ;
    UNLOCKQUEUES ; // RELEASE THE LOCK
  
    return getNextJob() ; // then we recursively go back and try
    // and getNextJob(), with a NEW front list in place.
    // If there are no more frontlists, then you'll eventually get NULL
  }
  
  WorkOrder* addJobForMainThread( Callback* job ) {
    return workOrderForMainThread->addJobQuietly( job ) ;
  }
  
  // A thread wants to continually run jobs as if it were in the fishTank,
  // but it is not in the fishTank.
  void runJobs() {
    while( Callback* job = getNextJob() )
    {
      job->exec() ;
      delete job ;
    }
    
    // When there are no more jobs, you drop out of the loop.
  }
  
  // These functions are intended to be called by mainthread ONLY
  void mainThreadBlockUntilAllJobsFinished( bool doBusyWait )
  {
    if( ![NSThread isMainThread] ) {
      puts( "ERROR: mainThreadBlockUntilAllJobsFinished() intended for use by main thread only. Not blocking." ) ;
      return ;
    }
    
    if( !numThreadsSwimming.read() ) {
      //puts( "mainThread: Nothing running, no need to block" ) ;
      return ;// no need to block if there are no swimming fish
    }
    
    if( doBusyWait )
      while( numThreadsSwimming.read() ) ;  // busy wait until all the workers go to sleep
      // (that's how we know all the jobs have been done. all the workers will be sleeping)
    else
      mainThread->sleep() ; // sleep until there are no more threads working on any jobs. noJobs() will be called
      // as the last fish goes to sleep.
  }
  
  void mainThreadRunJobs()
  {
    if( ![NSThread isMainThread] ) {
      puts( "ERROR: mainThreadRunJobs(): You're trying to run mainthread jobs on not the main thread. Not running them." ) ;
      return ;
    }
    
    // here, you are the main thread
    workOrderForMainThread->runAll() ;
  }
  
} ;

extern ThreadPool* threadPool ;



void testBackgroundWork() ;



#endif
