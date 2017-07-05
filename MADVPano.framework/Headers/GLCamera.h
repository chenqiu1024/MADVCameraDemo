//
//  GLCamera.hpp
//  Madv360_v1
//
//  Created by QiuDong on 16/4/27.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#ifndef GLCamera_hpp
#define GLCamera_hpp

#include "gles2.h"

#include "AutoRef.h"
#include "kazmath.h"
#include "OpenGLHelper.h"

#define CLIP_WIDTH    6
#define CLIP_Z_NEAR   0
#define CLIP_Z_FAR    65536

#define REFERENCE_VIEWPORT_WIDTH    375
#define REFERENCE_VIEWPORT_HEIGHT   667

class GLCamera {
    friend class PanoCameraController;
    
public:
    
    virtual ~GLCamera();
    
    GLCamera();
    
    void getProjectionMatrix(kmMat4* projectionMatrix);
    void getStereoGraphicProjectionMatrix(kmMat4* projectionMatrix);
    void getLittlePlanetProjectionMatrix(kmMat4* projectionMatrix);
    
    inline void setProjectionFrustum(GLint width, GLint height, GLint zNear, GLint zFar) {
        _width = width;
        _height = height;
        _near = zNear;
        _far = zFar;
    }
    
    inline GLint getWidth() {return _width;}
    inline void setWidth(GLint width) {_width = width;}
    
    inline GLint getHeight() {return _height;}
    inline void setHeight(GLint height) {_height = height;}
    
    inline GLfloat getZNear() {return _near;}
    inline void setZNear(GLfloat zNear) {_near = zNear;}
    
    inline GLfloat getZFar() {return _far;}
    inline void setZFar(GLfloat zFar) {_far = zFar;}
    
    inline GLint getFOVDegree() {return _fovDegree;}
    inline void setFOVDegree(GLint fovDegree) {_fovDegree = fovDegree;}
    
    inline GLint getViewSphereRadius() {return _viewSphereRadius;}
    inline void setViewSphereRadius(GLint viewSphereRadius) {_viewSphereRadius = viewSphereRadius;}

    void getViewMatrix(kmMat4* viewMatrix);

    void setCameraPostRotation(const kmQuaternion* cameraPostRotationQuaternion);
    void setCameraPostRotationMatrix(const kmMat4* cameraPostRotation);
    
    void setCameraPreRotation(const kmQuaternion* cameraPreRotationQuaternion);
    void setCameraPreRotationMatrix(const kmMat4* cameraPreRotation);
    
    void setCameraRotation(const kmQuaternion* cameraRotationQuaternion, bool isInversed);
    void setCameraRotationMatrix(const kmMat4* cameraRotation, bool isInversed);
    
    void setModelPreRotation(const kmQuaternion* modelPreRotationQuaternion);
    void setModelPreRotationMatrix(const kmMat4* modelPreRotation);
    
    void setModelRotation(const kmQuaternion* modelRotationQuaternion);
    void setModelRotationMatrix(const kmMat4* modelRotation);

    static void normalizeRotationMatrix(kmMat4* rotationMat);

    static bool checkVector(const kmVec3* vec);
    
    static bool checkRotationMatrix(const kmMat4* matrix, bool completeCheck, const char* tag);

    static bool checkQuaternion(const kmQuaternion* quaternion);
    
    static void normalizeQuaternion(kmQuaternion* quaternion);
    
    kmVec4 _debugGetPolarAxis();
    kmVec4 _debugGetNorthPolar();
    kmVec4 _debugGetSouthPolar();
    kmMat4 _debugGetCameraRotation();
    
protected:
    
//    void calculateCameraMatrix(kmMat4* outCameraMatrix);
//    Vec2f calculateModelMatrix(kmMat4* outModelMatrix, kmMat4* outYawMatrix, kmMat4* outPitchMatrix, const kmMat4* projectionMatrix);
    
private:
    
    void calculateDebugAxes();
    
    kmMat4 _cameraPreRotationMatrix;
    kmMat4 _cameraPostRotationMatrix;
    kmMat4 _cameraRotationMatrix;
    
    kmMat4 _modelPreRotationMatrix;
    kmMat4 _modelRotationMatrix;
    
    GLint _width;
    GLint _height;
    GLint _near;
    GLint _far;
    GLint _fovDegree;
    GLint _viewSphereRadius;
};

typedef AutoRef<GLCamera> GLCameraRef;

/**
 *  In World Coordinate System:
 *  modelMatrix = modelRotationMatrix * modelPreRotationMatrix; --- F1
 *  finalGLTransformMatrix = modelMatrix / cameraMatrix; --- F2
 *  modelRotationMatrix[0] = IdentityMatrix; --- F1.1
 *  modelRotationMatrix[k+1] = modelRotationMatrix[k] rotateAround@By@(yawAxis[k], yawAngle) rotateAround@By@(pitchAxis[k], pitchAngle); --- F1.2
 *  yawAxis[0] = Uw = [0,1,0]; --- F1.2.1
 *  yawAxis[k+1] = yawAxis[k] projectOn Plane{Fc, Uw}, if !(Fc ~~ Uw), when adustAxis on panning begin; --- F1.2.2
 *  yawAxis[k+1] = yawAxis[k] projectOn Plane{Uc, Uw}, if (Fc ~~ Uw), when adustAxis on panning begin; --- F1.2.3
 *  yawAxis[k+1] = yawAxis[k] rotateAround@By@(pitchAxis[k], pitchAngle), when panning; --- F1.2.4
 *  pitchAxis[0] = Rw = [1,0,0]; --- F1.2.5
 *  pitchAxis[k+1] = Fc cross Uw, if !(Fc ~~ Uw), when adustAxis on panning begin; --- F1.2.6
 *  pitchAxis[k+1] = Rc, if (Fc ~~ Uw), when adustAxis on panning begin; --- F1.2.7
 *
 *  Rc = cameraRotationMatrix * Rw; --- F1.2.7.1
 *  Fc = cameraRotationMatrix * Fw = cameraRotationMatrix * [0,0,-1]; --- F1.2.6.1
 *  yawAngle = k1? * length(panComponentInYawAxis) * sgn(panComponentInYawAxis dot Fc); --- F1.2.8.1
 *  panComponentInYawAxis = panDirectionVector cross yawAxis; --- F1.2.8.2
 *  pitchAngle = k2? * length(panComponentInPitchAxis) * sgn(panComponentInPitchAxis dot Fc); --- F1.2.8.3
 *  panComponentInPitchAxis = panDirectionVector cross pitchAxis; --- F1.2.8.4
 *
 *  modelMatrix = cameraMatrix, when reset view position; --- F3
 *
 *  yawAxis[k+1] = yawAxis[k] projectOn Plane{Fc, Uc}, when adustAxis on panning begin; --- F1.2.2B
 *  pitchAxis[k+1] = Fc cross Uc = Rc, when adustAxis on panning begin; --- F1.2.6B
 */
// F1: setModelPreRotation
// F2: setCameraRotationEndState, commitCameraRotation
// F1.2, F1.2.4|8: rotateModelByDragging, setDraggingEndState, commitDragging
// F1.2.2|3|6|7: adustAxis
// F3: resetViewPosition
#endif /* GLCamera_hpp */
