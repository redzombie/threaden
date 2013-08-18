#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#include <vector>
using namespace std ;

#import "Vectorf.h"

inline void addLine( vector<VertexPC>& verts, const Vector3f& a, const Vector3f& b, const Vector4f& color )
{
  verts.push_back( VertexPC( a, color ) ) ;
  verts.push_back( VertexPC( b, color ) ) ;
}

inline void addTri( vector<VertexPNC>& verts, const Vector3f& a, const Vector3f& b, const Vector3f& c, const Vector4f& color )
{
  Vector3f N = Triangle::triNormal( a, b, c ) ;
  verts.push_back( VertexPNC( a, N, color ) ) ;
  verts.push_back( VertexPNC( b, N, color ) ) ;
  verts.push_back( VertexPNC( c, N, color ) ) ;
}

void drawPC( const vector<VertexPC>& verts, int start, int count, GLenum drawMode ) ;
void drawPC( const vector<VertexPC>& verts, GLenum drawMode ) ;
void drawPNC( const vector<VertexPNC>& verts, GLenum drawMode ) ;

extern vector<VertexPC> pcVertsA, pcVertsB ;
extern vector<VertexPNC> pncVerts ;


@interface ES1Renderer : NSObject
{
@public
	EAGLContext *context ;
	
	// The pixel dimensions of the CAEAGLLayer
	GLint backingWidth;
	GLint backingHeight;
	
	// The OpenGL names for the framebuffer and renderbuffer used to render to this view
	GLuint defaultFramebuffer, colorRenderbuffer;
  
  // For parallelProcessAndDraw
  vector<VertexPC> *process, *draw ;
  
}

- (void) setupTransformations ;
- (void) prerender:(EAGLContext*)glContext ;

- (void) flipBuffers ;
- (void) runFrame ;
- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer;

@end
