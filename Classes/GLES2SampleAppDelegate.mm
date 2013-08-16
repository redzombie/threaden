#import "GLES2SampleAppDelegate.h"
#import "EAGLView.h"

@implementation GLES2SampleAppDelegate

@synthesize window;
@synthesize glView;

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
	[glView startAnimation];
  
  window.rootViewController = [[UIViewController alloc] init]; 
  window.rootViewController.view = glView; // MUST SET THIS UP OTHERWISE THE ROOTVIEWCONTROLLER SEEMS TO INTERCEPT TOUCH EVENTS
  
}

- (void) applicationWillResignActive:(UIApplication *)application
{
	[glView stopAnimation];
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
	[glView startAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[glView stopAnimation];
}

- (void) dealloc
{
	[window release];
	[glView release];
	
	[super dealloc];
}

@end
