//
//  OpenGLHelper.h
//  Madv360
//
//  Created by FutureBoy on 11/5/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#ifndef OpenGLHelper_h
#define OpenGLHelper_h

#include "gles2.h"
#include "gles2ext.h"
#include "mat3.h"
#include "mat4.h"
#include "AutoRef.h"
#include "Log.h"

#define CHECK_GL_ERROR() \
do { \
GLenum __error = glGetError(); \
if(__error) { \
ALOGE("OpenGL error 0x%04X in %s %s %d\n", __error, __FILE__, __FUNCTION__, __LINE__); \
} \
} while (false)

#define STRINGIZE0(...) __VA_ARGS__
#define STRINGIZE(...) #__VA_ARGS__
#define STRINGIZE2(...) STRINGIZE(__VA_ARGS__)
#define NSSTRINGIZE(...) @ STRINGIZE2(__VA_ARGS__)

typedef enum {
    OrientationNormal = 0,
    OrientationMirror = 1,
    OrientationRotateLeft = 2,
    OrientationRotateLeftMirror = 3,
    OrientationRotateRight = 4,
    OrientationRotateRightMirror = 5,
    OrientationRotate180Degree = 6,
    OrientationRotate180DegreeMirror = 7,
} Orientation2D;

#ifdef __cplusplus
extern "C" {
#endif
    
typedef struct Texcoord2fStruct {
    GLfloat s;
    GLfloat t;
} Texcoord2f;

typedef struct Size2fStruct {
    GLfloat width;
    GLfloat height;
} Size2f;

typedef struct Point2fStruct {
    GLfloat x;
    GLfloat y;
} Point2f;

typedef struct Vec2fUnion {
    union {GLfloat s; GLfloat width; GLfloat x;};
    union {GLfloat t; GLfloat height; GLfloat y;};
} Vec2f;
    
#define Vec2fZero   Vec2f{0,0}
    
typedef struct Color3fStruct {
    GLfloat r;
    GLfloat g;
    GLfloat b;
} Color3f;

typedef struct Vec3fStruct {
    union {GLfloat x; GLfloat r;};
    union {GLfloat y; GLfloat g;};
    union {GLfloat z; GLfloat b;};
} Vec3f;

typedef struct Vec4fStruct {
    union {GLfloat x; GLfloat r;};
    union {GLfloat y; GLfloat g;};
    union {GLfloat z; GLfloat b;};
    union {GLfloat w; GLfloat a;};
} Vec4f;
    
typedef struct P4C4T2fStruct {
    union {
        struct {
            GLfloat x;
            GLfloat y;
            GLfloat z;
            GLfloat w;
        };
        Vec4f position;
    };

    union {
        struct {
            GLfloat r;
            GLfloat g;
            GLfloat b;
            GLfloat a;
        };
        Vec4f color;
    };

    union {
        struct {
            GLfloat s;
            GLfloat t;
        };
        Vec2f texcoord;
    };
} P4C4T2f;

typedef struct QuadfStruct {
    P4C4T2f leftbottom;
    P4C4T2f lefttop;
    P4C4T2f righttop;
    P4C4T2f rightbottom;
} Quadf;

inline bool Vec2fEqualToPoint(Vec2f vec0, Vec2f vec1) {
    return (vec0.x == vec1.x && vec1.y == vec0.y);
}

unsigned long nextPOT(unsigned long x);

int ComponentsOfColorSpace(GLenum colorspace);

int BytesOfBitFormat(GLenum bitformat);

float* transformMatrixInNormalizedCoordSystem2D(float* matrix, int rank, Vec2f viewportOrigin, Vec2f viewportSize, Vec2f boundOrigin, Vec2f boundSize, Orientation2D orientation);
kmMat3* transformMatrix3InNormalizedCoordSystem2D(kmMat3* mat, Vec2f viewportOrigin, Vec2f viewportSize, Vec2f boundOrigin, Vec2f boundSize, Orientation2D orientation);
kmMat4* transformMatrix4InNormalizedCoordSystem2D(kmMat4* mat, Vec2f viewportOrigin, Vec2f viewportSize, Vec2f boundOrigin, Vec2f boundSize, Orientation2D orientation);

GLint compileShader(const GLchar* const* shaderSources, int sourcesCount, GLenum type);

GLint compileAndLinkShaderProgram(const GLchar* const* vertexSources, int vertexSourcesCount,
                                  const GLchar* const* fragmentSources, int fragmentSourcesCount);

GLint compileAndLinkShaderProgramWithShaderPointers(const GLchar* const* vertexSources, int vertexSourcesCount,
                                                    const GLchar* const* fragmentSources, int fragmentSourcesCount,
                                                    GLint* pVertexShader, GLint* pFragmentShader);

void createOrUpdateTexture(GLuint* pTextureID, GLint width, GLint height, GLubyte** pTextureData, GLsizei* pTextureDataSize, void(*dataSetter)(GLubyte* data, GLint pow2Width, GLint pow2Height, void* userData), void* userData);

P4C4T2f P4C4T2fMake(GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLfloat r, GLfloat g, GLfloat b, GLfloat a, GLfloat s, GLfloat t);

#ifdef __cplusplus
}
#endif

class DrawablePrimitive {
    friend class GLVAO;
    friend class Mesh3D;

public:
    virtual ~DrawablePrimitive();

    GLshort* indices = NULL;
    GLsizei indexCount = 0;
    GLenum type = GL_TRIANGLE_STRIP;
};

typedef AutoRef<DrawablePrimitive> DrawablePrimitiveRef;

class Mesh3D {
    friend class GLVAO;

public:
    virtual ~Mesh3D();
    Mesh3D(int vertexCount, int primitiveCount);

    bool copy(const Mesh3D& other);

    static Mesh3D* createSphere(GLfloat radius, int longitudeSegments, int latitudeSegments, bool flipX, bool flipY);
    static Mesh3D* createSphereV0(GLfloat radius, int longitudeSegments, int latitudeSegments, bool flipX, bool flipY);

    static Mesh3D* createGrids(GLfloat width, GLfloat height, int columns, int rows, bool flipX, bool flipY);
    static Mesh3D* createRedundantGrids(GLfloat width, GLfloat height, int columns, int rows, bool flipX, bool flipY);

    static Mesh3D* createQuad(P4C4T2f v0, P4C4T2f v1, P4C4T2f v2, P4C4T2f v3);

    static Mesh3D* createTrivialQuad();

    static Mesh3D* createMeshWithContinuousVertices(P4C4T2f* vertices, int count, int primitiveType);
    
    static Mesh3D* createSphereGaps(GLfloat radius, GLfloat topTheta, GLfloat bottomTheta, GLfloat ratio);

    P4C4T2f* vertices = NULL;
    GLsizei vertexCount;

    DrawablePrimitiveRef* primitives = NULL;
    GLsizei primitiveCount;
};

typedef AutoRef<Mesh3D> Mesh3DRef;
    
class GLVAO {
public:
    virtual ~GLVAO() {
        releaseGLObjects();
    }

    GLVAO(Mesh3DRef mesh, GLenum usageHint);

    void refreshData(Mesh3DRef mesh, GLenum usageHint);
    
    void releaseGLObjects();

    void draw(int positionSlot, int colorSlot, int texcoordSlot);

    void drawMadvSphere(int positionSlot, int vertexRoleSlot, int dstTexcoordSlot);

protected:
    GLint vao = -1;
    GLint vertexBuffer = -1;
    GLuint* indexBuffers = NULL;
    Mesh3DRef mesh;
};

typedef AutoRef<GLVAO> GLVAORef;
    
#endif /* OpenGLHelper_h */
