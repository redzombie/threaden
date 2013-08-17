#ifndef VECTORF_H
#define VECTORF_H

// random between 0 and 1
inline float randFloat()
{
  // arc4random() is 0..4B (UINT_MAX).  It is NOT ULONG_MAX.
  // on ios ULONG_MAX=UINT_MAX, but on mac ULONG_MAX is ULONGLONG_MAX (9 trillion million or whatever)
  return (float)arc4random() / UINT_MAX ;
}

// -1,1 => -1 + ( rand between 0 and 2 )
inline float randFloat( float low, float high )
{
  //return low + ((float)arc4random() / UINT_MAX)*(high-low) ;
  return low + (high-low)*randFloat() ;
}

// Stripped down versions of these structs
union Vector3f
{
  struct{ float x,y,z ; } ;
  float elts[3];
  
  Vector3f():x(0.f),y(0.f),z(0.f){}
  Vector3f( float ix, float iy, float iz ):x(ix),y(iy),z(iz){}
  Vector3f( float iv ):x(iv),y(iv),z(iv){}
  
  static inline Vector3f random() { return Vector3f( randFloat(), randFloat(), randFloat() ) ;  }
  
  static inline Vector3f random(float min, float max) {
    return Vector3f( randFloat(min,max), randFloat(min,max), randFloat(min,max) ) ;
  }
  static inline Vector3f random(const Vector3f& min, const Vector3f& max) {
    return Vector3f( randFloat(min.x,max.x), randFloat(min.y,max.y), randFloat(min.z,max.z) ) ;
  }
  
  // 9 op
  inline Vector3f cross( const Vector3f& o ) const {
    return Vector3f( y*o.z-o.y*z, z*o.x-x*o.z, x*o.y-o.x*y ) ;
  }
  // 5 op
  inline float dot( const Vector3f& o ) const {
    return x*o.x+y*o.y+z*o.z ;
  }
  
  inline float len() const {
    return sqrtf( x*x+y*y+z*z ) ;
  }
  
  inline Vector3f& normalize(){
    float length = len() ;
    
    // I added this debug check man, never take it out.
    if( !length ) {
      puts( "Vector3f::normalize() attempt to divide by 0" ) ;
      return *this ;
    }
    
    return (*this)/=length ;
  }
  
  // Exact equality
  inline bool operator==( const Vector3f& o ) const{
    return x==o.x && y==o.y && z==o.z ;
  }
  // Exact inequality
  inline bool operator!=( const Vector3f& o ) const{
    return x!=o.x || y!=o.y || z!=o.z ;
  }
  
  inline Vector3f operator+( const Vector3f& o ) const {
    return Vector3f(x+o.x,y+o.y,z+o.z);
  }
  inline Vector3f operator+( float o ) const {
    return Vector3f(x+o,y+o,z+o);
  }
  
  inline Vector3f operator-() const{
    return Vector3f(-x,-y,-z);
  }
  inline Vector3f operator-( const Vector3f& o ) const {
    return Vector3f(x-o.x,y-o.y,z-o.z);
  }
  inline Vector3f operator-( float o ) const {
    return Vector3f(x-o,y-o,z-o);
  }
  
  inline Vector3f operator*( const Vector3f& o ) const {
    return Vector3f(x*o.x,y*o.y,z*o.z);
  }
  inline Vector3f operator*( float s ) const {
    return Vector3f(x*s,y*s,z*s);
  }
  
  inline Vector3f operator/( const Vector3f& o ) const {
    return Vector3f(x/o.x,y/o.y,z/o.z);
  }
  inline Vector3f operator/( float s ) const {
    return Vector3f(x/s,y/s,z/s);
  }
  inline Vector3f& operator+=( const Vector3f& o ){
    x+=o.x,y+=o.y,z+=o.z;
    return *this ;
  }
  inline Vector3f& operator+=( float s ){
    x+=s,y+=s,z+=s;
    return *this ;
  }
  inline Vector3f& operator-=( const Vector3f& o ){
    x-=o.x,y-=o.y,z-=o.z;
    return *this ;
  }
  inline Vector3f& operator-=( float s ){
    x-=s,y-=s,z-=s;
    return *this ;
  }
  inline Vector3f& operator*=( const Vector3f& o ){
    x*=o.x,y*=o.y,z*=o.z;
    return *this ;
  }
  inline Vector3f& operator*=( float s ){
    x*=s,y*=s,z*=s;
    return *this ;
  }
  inline Vector3f& operator/=( const Vector3f& o ){
    x/=o.x,y/=o.y,z/=o.z;
    return *this ;
  }
  inline Vector3f& operator/=( float s ){
    x/=s,y/=s,z/=s;
    return *this ;
  }
} ;

union Matrix3f
{
  struct { float m00,m01,m02,
                 m10,m11,m12,
                 m20,m21,m22 ; } ;
  float elts[9] ;
  
  Matrix3f():
    // IDENTITY
    m00(1),m01(0),m02(0),
    m10(0),m11(1),m12(0),
    m20(0),m21(0),m22(1)
  { }

  Matrix3f( float im00, float im01, float im02,
            float im10, float im11, float im12,
            float im20, float im21, float im22 ) :
    m00(im00), m01(im01), m02(im02),
    m10(im10), m11(im11), m12(im12),
    m20(im20), m21(im21), m22(im22)
  { }
  
  Matrix3f( const Vector3f& right, const Vector3f& up, const Vector3f& forward ) :
    m00(right.x), m01(up.x), m02(-forward.x),
    m10(right.y), m11(up.y), m12(-forward.y),
    m20(right.z), m21(up.z), m22(-forward.z)
  { }
  
  inline int getIndex( int iCol, int iRow ) const {
    return iCol*3 + iRow ;
  }
  inline Vector3f row( int iRow ) const {
    return Vector3f( elts[getIndex(0,iRow)], elts[getIndex(1,iRow)], elts[getIndex(2,iRow)] ) ;
  }
  inline Vector3f col( int iCol ) const {
    return Vector3f( elts[getIndex(iCol,0)], elts[getIndex(iCol,1)], elts[getIndex(iCol,2)] ) ;
  }
  inline Matrix3f& transpose() {
    swap( m10, m01 ) ;
    swap( m20, m02 ) ;
    swap( m21, m12 ) ;
    return *this ;
  }
  // 17 ops
  static float det( const Vector3f& a, const Vector3f& b, const Vector3f& c )
  {
    // The determinant the transpose=det original matrix, so it doesn't matter if we consider a,b,c, the cols or rows of A.
    // |A| = |A^T|,
    
    // │ a.x b.x c.x │ a.x b.x
    // │ a.y b.y c.y │ a.y b.y
    // │ a.z b.z c.z │ a.z b.z

    // │ a.x a.y a.z │ a.x a.y
    // │ b.x b.y b.z │ b.x b.y
    // │ c.x c.y c.z │ c.x c.y

    // "down product minus up product"
    // omg u of t was good for something.
    return a.x*b.y*c.z + b.x*c.y*a.z + c.x*a.y*b.z - a.z*b.y*c.x - b.z*c.y*a.x - c.z*a.y*b.x ;
    
    // transpose would be (consider this "cross checking")
    // return a.x*b.y*c.z + a.y*b.z*c.x + a.z*b.x*c.y - c.x*b.y*a.z - c.y*b.z*a.x - c.z*b.x*a.y
  }

  inline static Matrix3f rotation( const Vector3f& u, float radians )
  {
    float c = cosf( radians ) ;
    float l_c = 1 - c ;
    float s = sinf( radians ) ;
    
    // COLUMN MAJOR
    return Matrix3f(
      u.x*u.x + (1.f - u.x*u.x)*c,   u.x*u.y*l_c - u.z*s,   u.x*u.z*l_c + u.y*s,
      u.x*u.y*l_c + u.z*s,   u.y*u.y+(1.f - u.y*u.y)*c,   u.y*u.z*l_c - u.x*s,
      u.x*u.z*l_c - u.y*s,   u.y*u.z*l_c + u.x*s,   u.z*u.z + (1.f - u.z*u.z)*c
    )   ;
  }
  
  inline static Matrix3f rotationX( float radians )
  {
    float c = cosf( radians ) ;
    float s = sinf( radians ) ;
    
    //   ^ y
    //   |
    // <-o
    // z  x
    
    // COLUMN MAJOR, RH
    return Matrix3f(
      1, 0, 0, // COLUMN 1
      0, c, s,
      0,-s, c
    ) ;
  }
  
  inline static Matrix3f rotationY( float radians )
  {
    float c = cosf( radians ) ;
    float s = sinf( radians ) ;
    
    //z
    // <-oy
    //   |
    //   vx
    //
    
    // COLUMN MAJOR, [ 1 0 0 ] ->90y-> [ 0 0 -1 ]
    //   so z value has -sin, ie 3rd row
    return Matrix3f(
      c, 0,-s, // COLUMN 1
      0, 1, 0,
      s, 0, c
    ) ;
  }
  
  inline static Matrix3f rotationZ( float radians )
  {
    float c = cosf( radians ) ;
    float s = sinf( radians ) ;
    
    // ^y
    // |
    // o->x
    //z
    
    // COLUMN MAJOR
    return Matrix3f(
      c, s, 0, // COLUMN 1
     -s, c, 0,
      0, 0, 1
    ) ;
  }
  
  // Y,X,Z
  inline static Matrix3f rotationYawPitchRoll( float radiansYaw, float radiansPitch, float radiansRoll )
  {
    // COLUMN MAJOR so yaw first, yaw at right
    return rotationZ( radiansRoll ) * rotationX( radiansPitch ) * rotationY( radiansYaw ) ;
  }
  
  // COLUMN MAJOR:
  // FIRST INDEX=COLUMN, SECOND INDEX=ROW
  // m00  m10  m20  [o.x]
  // m01  m11  m12  [o.y]
  // m02  m12  m22  [o.z]
  // post multiply only
  inline Vector3f operator*( const Vector3f& o ) const
  {
    // ┌             ┐   ┌   ┐   ┌                       ┐
    // │ m00 m10 m20 │   │ x │   │ m00*x + m10*y + m20*z │
    // │ m01 m11 m21 │ * │ y │ = │ m01*x + m11*y + m21*z │
    // │ m02 m12 m22 │   │ z │   │ m02*x + m12*y + m22*z │
    // └             ┘   └   ┘   └                       ┘
    return Vector3f(
      o.x*m00 + o.y*m10 + o.z*m20,  //o.dot( *(Vector3f*)(&m00) ), // this won't inline
      o.x*m01 + o.y*m11 + o.z*m21,
      o.x*m02 + o.y*m12 + o.z*m22
    ) ;
  }
  
  Matrix3f operator*( const Matrix3f& o ) const
  {
    Matrix3f m ;
    
    // 0 4  8 12
    // 1 5  9 13
    // 2 6 10 14
    // 3 7 11 15
    
    // 0 3 6   0 3 6
    // 1 4 7   1 4 7
    // 2 5 8   2 5 8
    
    m.elts[0]  = elts[0] * o.elts[0]  + elts[3] * o.elts[1]  + elts[6] * o.elts[2] ;
    m.elts[1]  = elts[1] * o.elts[0]  + elts[4] * o.elts[1]  + elts[7] * o.elts[2] ;
    m.elts[2]  = elts[2] * o.elts[0]  + elts[5] * o.elts[1]  + elts[8] * o.elts[2] ;
    
    m.elts[3]  = elts[0] * o.elts[3]  + elts[3] * o.elts[4]  + elts[6] * o.elts[5] ;
    m.elts[4]  = elts[1] * o.elts[3]  + elts[4] * o.elts[4]  + elts[7] * o.elts[5] ;
    m.elts[5]  = elts[2] * o.elts[3]  + elts[5] * o.elts[4]  + elts[8] * o.elts[5] ;
    
    m.elts[6]  = elts[0] * o.elts[6]  + elts[3] * o.elts[7]  + elts[6] * o.elts[8] ;
    m.elts[7]  = elts[1] * o.elts[6]  + elts[4] * o.elts[7]  + elts[7] * o.elts[8] ;
    m.elts[8]  = elts[2] * o.elts[6]  + elts[5] * o.elts[7]  + elts[8] * o.elts[8] ;
    
    return m;
  }
  
  void println() const {
    for( int i = 0 ; i < 3 ; i++ )
    {
      // Because printf works horizontally, we have to print out each ROW.
      for( int j = 0 ; j < 3 ; j++ )
        printf( "%8.3f ", elts[ getIndex( j, i ) ] ) ;
      puts("");
    }
    puts("");
  }
} ;


union Vector4f
{
  struct{ float x,y,z,w ; } ;
  struct{ float r,g,b,a ; } ;
  float elts[4];
  
  Vector4f():x(0.f),y(0.f),z(0.f),w(1.f){}
  Vector4f( float ix, float iy, float iz ):x(ix),y(iy),z(iz),w(1.f){}
  Vector4f( float ix, float iy, float iz, float iw ):x(ix),y(iy),z(iz),w(iw){}
  Vector4f( const Vector3f& o, float iw ):x(o.x),y(o.y),z(o.z),w(iw){}
  Vector4f( const Vector3f& v3f ):x(v3f.x),y(v3f.y),z(v3f.z),w(1.f){}
  Vector4f( float iv ):x(iv),y(iv),z(iv),w(iv){}
  
  static inline Vector4f random() { return Vector4f( randFloat(), randFloat(), randFloat(), 1.f ) ;  }
  
  static inline Vector4f random(float min, float max) {
    return Vector4f( randFloat(min,max), randFloat(min,max), randFloat(min,max), 1.f ) ;
  }
} ;





struct Triangle
{
  // a, b, c should be wound CCW
  static inline Vector3f triNormal( const Vector3f& a, const Vector3f& b, const Vector3f& c )
  {
    // CCW NORMAL
    Vector3f crossProduct = ( b - a ).cross( c - a ) ;
    return crossProduct.normalize() ;
  }
} ;






struct VertexPC
{
  Vector3f pos ;
  Vector4f color ;
  
  VertexPC(){}
    
  VertexPC( const Vector3f& iPos, const Vector4f& iColor ) :
    pos( iPos ), color( iColor )
  {
    
  }
} ;

struct VertexPNC
{
  Vector3f pos ;
  Vector3f normal ;
  Vector4f color ;
  
  VertexPNC(){}
    
  VertexPNC( const Vector3f& iPos, const Vector3f& iNormal, const Vector4f& iColor ) :
    pos( iPos ), normal( iNormal ), color( iColor )
  {
    
  }
} ;

#endif