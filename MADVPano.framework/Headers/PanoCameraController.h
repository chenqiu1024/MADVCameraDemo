//
//  PanoCameraController.hpp
//  Madv360_v1
//  通过用户输入设备（屏幕触控、陀螺仪）控制全景内容的显示视角
//  Created by DOM QIU on 2017/6/14.
//  Copyright © 2017年 Cyllenge. All rights reserved.
//

#ifndef PanoCameraController_hpp
#define PanoCameraController_hpp

#include "GLCamera.h"
#include "MadvGLRenderer.h"

typedef enum {
    PanoControlStateIdle,
    PanoControlStateGyro,
//    PanoControlStatePostGyroAdjust,
    PanoControlStateTouch,
//    PanoControlStatePostTouchAdjust,
    PanoControlStateFling,
} PanoControlState;

class PanoCameraController {
public:
// 以下凡是不加注释的public方法或者是SDK内部使用，或者是相对低级因而调用者可以不用关心，在平台相关的子类（iOS上是#PanoCameraController_iOS#）中有更好的封装接口
    virtual ~PanoCameraController();
    
    /** 构造函数：以#MadvGLRenderer#对象创建
     * @param panoRenderer 已创建的MadvGLRenderer对象的#AutoRef#指针
     */
    PanoCameraController(MadvGLRendererRef panoRenderer);
    
    /** 设置FOV角度值 */
    void setFOVDegree(int degree);
    
    PanoCameraController(GLCameraRef panoCamera);
    
    void setCamera(GLCameraRef panoCamera);
    
    bool getViewMatrix(kmMat4* viewMatrix);
    
    /** 使能或禁止俯仰角方向的手势拖动
     * 目前实践中效果比较好的控制方式是（仿Theta）:
     * 当使用手机陀螺仪控制时，为避免手势拖动的偏航轴被转歪的问题，要禁止俯仰角的拖动控制
     * 而当关闭手机陀螺仪控制时，才使能俯仰角的拖动控制
     * （在VR模式下可以有更好的处理方式，但目前还有问题正在解决中）
     */
    inline void setEnablePitchDragging(bool enablePitchDragging) {_enablePitchDragging = enablePitchDragging;}
    
    inline bool getEnablePitchDragging() {return _enablePitchDragging;}
    
    /** 在每一帧图像绘制时调用，用于动画的更新
     * @param dtSeconds 以秒计的帧间隔时间
     */
    void update(float dtSeconds);
    
    void setScreenOrientation(Orientation2D orientation);
    
    void setGyroRotationQuaternion(kmQuaternion* inertialGyroQuaternion, bool isInversed);
    
    void setInertiaGyroRotation(kmQuaternion* inertialGyroQuaternion, bool isInversed);
    
    void startGyroControl(kmQuaternion* startInertialGyroRotation, bool isInversed);
    void startGyroControl();
    
    void stopGyroControl();
    
    void startTouchControl(kmVec2 normalizedTouchPoint);
    
    void setDragPoint(kmVec2 normalizedTouchPoint);
    
    void stopTouchControl(kmVec2 normalizedVelocity);
    
    void setVirtualCameraPreRotationMatrix(const kmMat4* virtualCameraPreRotationMatrix);
    
    /** Set direction of looking with Euler angles:
     *  
     */
    void lookAt(float yawDegrees, float pitchDegrees, float bankDegrees);
    
    void resetViewPosition();
    
    void adjustDragAxis();
    
protected:
    
    inline PanoControlState getState() {return _state;}
    inline void setState(PanoControlState state) {_state = state;}
    
private:
    
    void calculateVirtualCameraRotationMatrix(kmMat4* virtualCameraRotationMatrix);
    void calcAndSetVirtualCameraRotationMatrixIfNecessary(kmMat4* virtualCameraRotationMatrix, bool invalidate);
    
    void calculateVirtualCameraPreRotationMatrix(kmMat4* virtualCameraPreRotationMatrix);
    void calcAndSetVirtualCameraPreRotationMatrixIfNecessary(kmMat4* virtualCameraPreRotationMatrix, bool invalidate);
    
    void calculateModelRotationMatrix(kmMat4* modelRotationMatrix, const kmMat4* virtualCameraRotationMatrix);
    void calcAndSetModelRotationMatrixIfNecessary(kmMat4* modelRotationMatrix, const kmMat4* virtualCameraRotationMatrix, bool invalidate);
    
    bool _enablePitchDragging;
    
    GLCameraRef _camera;
    PanoControlState _state;
    
    Orientation2D _screenOrientation;
    
    kmMat4 _virtualCameraPreRotationMatrix0;
    kmMat4 _virtualCameraPreBankRotationMatrix;
    
    kmQuaternion _inertialGyroRotation;
    kmQuaternion _startInertialGyroRotation;
    kmQuaternion _baseVirtualGyroRotation;
    
    kmQuaternion _baseModelRotation;
    
    kmVec2 _startDragPoint;
    kmVec2 _currentDragPoint;
    
    float _angleVelocityDeceleration;
    float _angleVelocity;
    float _diffAngle;
    float _accumulatedAngle;
    kmVec2 _diffYawAndPitch;
    kmVec3 _yawAxis;
    kmVec3 _pitchAxis;
    
    bool _isVirtualCameraRotationInvalid;
    bool _isVirtualCameraPreRotationInvalid;
    bool _isModelRotationInvalid;
};

typedef AutoRef<PanoCameraController> PanoCameraControllerRef;

#endif /* PanoCameraController_hpp */
