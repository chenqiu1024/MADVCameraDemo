//
//  MadvGLRenderer.h
//  Madv360_v1
//  全景渲染器，封装了与渲染全景内容有关的OpenGL调用，
//  本身不包含与OpenGL context创建/切换/销毁相关的代码，这部分内容由调用者完成
//  Created by QiuDong on 16/2/26.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#ifndef MadvGLRenderer_hpp
#define MadvGLRenderer_hpp

#include "OpenGLHelper.h"
#include "GLProgram.h"
#include "GLCamera.h"
#include "kazmath.h"
#include <pthread.h>
#ifdef TARGET_OS_WINDOWS
#pragma comment(lib, "pthreadVC2.lib")
#endif
#include <map>

/** 全景显示模式标志值 */
typedef enum {
    PanoramaDisplayModePlain = 0x00,
    PanoramaDisplayModeSphere = 0x01,
    PanoramaDisplayModeLittlePlanet = 0x02,
    PanoramaDisplayModeStereoGraphic = 0x03,
    PanoramaDisplayModeReFlatten = 0x04,
    PanoramaDisplayModeReFlattenInVertex = 0x05,

	PanoramaDisplayModeLUT = 0x10,
    PanoramaDisplayModePlainStitch = 0x20,

    PanoramaDisplayModeExclusiveMask = 0x0f,
} PanoramaDisplayMode;

#pragma mark    GLSL Shaders

class MadvGLProgram : public GLProgram {
public:
    
    MadvGLProgram(const GLchar* const* vertexSources, int vertexSourcesCount, const GLchar* const* fragmentSources, int fragmentSourcesCount);
    
    inline GLint getLeftTextureSlot() {return _leftTextureSlot;}
    inline GLint getRightTextureSlot() {return _rightTextureSlot;}
    
    inline GLint getVertexRoleSlot() {return _vertexRoleSlot;}
    inline GLint getDiffTexcoordSlot() {return _diffTexcoordSlot;}
    inline GLint getDstSizeSlot() {return _dstSizeSlot;}
    inline GLint getLeftSrcSizeSlot() {return _leftSrcSizeSlot;}
    inline GLint getRightSrcSizeSlot() {return _rightSrcSizeSlot;}
    
    inline GLint getLeftYTextureSlot() {return _yLeftTextureSlot;}
    inline GLint getLeftUTextureSlot() {return _uLeftTextureSlot;}
    inline GLint getLeftVTextureSlot() {return _vLeftTextureSlot;}
    inline GLint getRightYTextureSlot() {return _yRightTextureSlot;}
    inline GLint getRightUTextureSlot() {return _uRightTextureSlot;}
    inline GLint getRightVTextureSlot() {return _vRightTextureSlot;}

    inline GLint getLUTTextureSlot() {return _lutTextureSlot;}

    inline GLint getTextureMatrixSlot() {return _textureMatrixSlot;}

    inline GLint getSPCMMatrixSlot() {return _SPCMMatrixSlot;}
    inline GLint getCMMatrixSlot() {return _CMMatrixSlot;}

protected:
    
    GLint _leftTextureSlot;
    GLint _rightTextureSlot;
    
    GLint _vertexRoleSlot;
    GLint _diffTexcoordSlot;
    
    GLint _dstSizeSlot;
    GLint _leftSrcSizeSlot;
    GLint _rightSrcSizeSlot;
    
    GLint _yLeftTextureSlot;
    GLint _uLeftTextureSlot;
    GLint _vLeftTextureSlot;
    GLint _yRightTextureSlot;
    GLint _uRightTextureSlot;
    GLint _vRightTextureSlot;

    GLint _lutTextureSlot;

    GLint _textureMatrixSlot;

    GLint _SPCMMatrixSlot;
    GLint _CMMatrixSlot;
};

typedef AutoRef<MadvGLProgram> MadvGLProgramRef;

/** 全景渲染器，封装了与渲染全景内容有关的OpenGL调用，
 * 本身不包含与OpenGL context创建/切换/销毁相关的代码，这部分内容由调用者完成
 */
class MadvGLRenderer {
    friend class PanoCameraController;
    
public:
    
    virtual ~MadvGLRenderer();
    
    /** 构造函数：基于拼接查找表文件参数创建渲染器
     * 拼接查找表文件用于将MADV相机拍摄的双鱼眼照片/视频拼接为全景
     * 查找表文件通过MADV相机下发或在MADV相机采集视频的MP4 box中获得
     * 获取和解压缩查找表文件的有关API在MADVCamera SDK中
     * @param lutPath 拼接双鱼眼图所用查找表文件的本地路径
     * @param leftSrcSize 左鱼眼图的查找表源尺寸，目前统一为3456x1728
     * @param leftSrcSize 左鱼眼图的查找表源尺寸，目前统一为3456x1728
     */
    MadvGLRenderer(const char* lutPath, Vec2f leftSrcSize, Vec2f rightSrcSize);
    
    /** 重设查找表文件参数。见构造函数的注释 */
    void prepareLUT(const char* lutPath, Vec2f leftSrcSize, Vec2f rightSrcSize);
    
    /** 在指定矩形区域中用指定的源RGB纹理图像绘制
     * @param displayMode 全景显示模式标志值，见#PanoramaDisplayMode#
     * @param separateSourceTextures 源纹理是否为分立式双鱼眼纹理。目前对于米家全景相机，始终为false
     * @param srcTextureType 源纹理的target，即GL_TEXTURE_2D或GL_TEXTURE_EXTERNAL_OES(Android常用)
     * @param leftSrcTexture 左(鱼眼)源纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param rightSrcTexture 右(鱼眼)源纹理。目前对于米家全景相机，左右源纹理是同一个
     */
    void draw(int displayMode, int x, int y, int width, int height, bool separateSourceTextures, int srcTextureType, int leftSrcTexture, int rightSrcTexture);
    
    /** 在指定矩形区域中用指定的源YUV纹理图像绘制
     * @param displayMode 全景显示模式标志值，见#PanoramaDisplayMode#
     * @param separateSourceTextures 源纹理是否为分立式双鱼眼纹理。目前对于米家全景相机，始终为false
     * @param srcTextureType 源纹理的target，即GL_TEXTURE_2D或GL_TEXTURE_EXTERNAL_OES(Android常用)
     * @param leftSrcYUVTextures 左(鱼眼)源YUV纹理数组，从[0]到[2]分别为Y、U、V纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param rightSrcYUVTextures 右(鱼眼)源YUV纹理，从[0]到[2]分别为Y、U、V纹理。目前对于米家全景相机，左右源纹理是同一个
     */
	void draw(int displayMode, int x, int y, int width, int height, bool separateSourceTextures, int srcTextureType, int* leftSrcYUVTextures, int* rightSrcYUVTextures);

    /** 在指定矩形区域中绘制。比前两个draw()方法所缺少的参数通过相应的设置方法预先设置好 */
    void draw(GLint x, GLint y, GLint width, GLint height);
    
    /** 属性: displayMode. 见#PanoramaDisplayMode# */
    inline int getDisplayMode() {return _currentDisplayMode;}
    inline void setDisplayMode(int displayMode) {_currentDisplayMode = displayMode;}
    
    /** 属性: 源纹理是否为YUV */
    inline bool getIsYUVColorSpace() {return _isYUVColorSpace;}
    inline void setIsYUVColorSpace(bool isYUVColorSpace) {_isYUVColorSpace = isYUVColorSpace;}
    
    /** 设置源RGB纹理
     * @param separateSourceTextures 源纹理是否为分立式双鱼眼纹理。目前对于米家全景相机，始终为false
     * @param srcTextureTarget 源纹理的target，即GL_TEXTURE_2D或GL_TEXTURE_EXTERNAL_OES(Android常用)
     * @param srcTextureL 左(鱼眼)源纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param srcTextureR 右(鱼眼)源纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param isYUVColorSpace 是否为YUV纹理，应固定传false。此处应该不需要该参数
     */
    void setSourceTextures(bool separateSourceTexture, GLint srcTextureL, GLint srcTextureR, GLenum srcTextureTarget, bool isYUVColorSpace);
    
    /** 设置源YUV纹理
     * @param separateSourceTextures 源纹理是否为分立式双鱼眼纹理。目前对于米家全景相机，始终为false
     * @param srcTextureTarget 源纹理的target，即GL_TEXTURE_2D或GL_TEXTURE_EXTERNAL_OES(Android常用)
     * @param srcTextureL 左(鱼眼)源YUV纹理数组，从[0]到[2]分别为Y、U、V纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param srcTextureR 右(鱼眼)源YUV纹理数组，从[0]到[2]分别为Y、U、V纹理。目前对于米家全景相机，左右源纹理是同一个
     * @param isYUVColorSpace 是否为YUV纹理，应固定传true。此处应该不需要该参数
     */
    void setSourceTextures(bool separateSourceTexture, GLint* srcTextureL, GLint* srcTextureR, GLenum srcTextureTarget, bool isYUVColorSpace);
    
    /** 设置源纹理的变换矩阵
     * 常见用途是在某些安卓机型上，由于其不支持NPOT纹理，解码出的纹理图像会有一部分是无效空白区域，
     * 这种情况下可通过SurfaceTexture的方法获得纹理变换矩阵，以得到正确的渲染结果
     */
    void setTextureMatrix(const kmMat4* textureMatrix);

    /** 查询已设置的源纹理相关属性值 */
    inline GLint getLeftSourceTexture() {return _srcTextureL;}
    inline GLint getRightSourceTexture() {return _srcTextureR;}
    inline GLenum getSourceTextureTarget() {return _srcTextureTarget;}
    
    /** 设置防抖陀螺仪旋转矩阵数据
     * MADV相机可以通过内置的6轴陀螺仪获取拍摄时的旋转数据，渲染时可藉此抵消较低频的旋转和抖动
     * @param matrix 相机陀螺仪输出的旋转矩阵数据，列优先。坐标系定义按照MADV相机的陀螺仪坐标系定义
     @ @param rank 矩阵阶数，一般固定设置为3
     */
    void setGyroMatrix(float* matrix, int rank);
    
    /** 是否要上下镜像 */
    inline void setFlipY(bool flipY) {_flipY = flipY;}
    
    /** 是否需要绘制底部Logo */
    inline void setNeedDrawCaps(bool drawCaps) {_drawCaps = drawCaps;}

    /** 设置底部Logo的纹理 */
    void setCapsTexture(GLint texture, GLenum textureTarget);
    
    /** 用任何可用的对象生成纹理并设置为源纹理
     * @param renderSource 用于生成源纹理的无类型对象指针
     * setRenderSource内部调用#prepareTextureWithRenderSource#方法从无类型对象生成源纹理并设置源纹理相关的属性值
     * 具体参见#prepareTextureWithRenderSource#方法的说明
     */
    void setRenderSource(void* renderSource);
    
    /** 获取源纹理图像的大小。一般不常用，可以在#prepareTextureWithRenderSource#的具体实现中设置 */
    inline Vec2f getRenderSourceSize() {return _renderSourceSize;}
    
    inline void setEnableDebug(bool enableDebug) {_enableDebug = enableDebug;}

    static void clearCachedLUT(const char* lutPath);

    inline GLCameraRef glCamera() {return _glCamera;}

	static void extractLUTFiles(const char* destDirectory, const char* lutBinFilePath, uint32_t fileOffset);

protected:
    
    /** 通过无类型对象设置源纹理，需要平台相关的子类具体实现
     * 具体实现中，当可以通过传入的无类型对象设置源纹理时，必须通过某个#setSourceTextures#方法将生成的纹理设置为源纹理
     * 非必须设置源纹理图像的尺寸_renderSourceSize
     * 如何从无类型对象生成源纹理是平台相关的，例如MadvGLRenderer_iOS上的实现是把无类型指针转换为id，
     * 然后判断其类型，如果是UIImage则生成对应的图像纹理，如果是NSString并且字符串表示一个有效的本地JPEG文件则通过JPEG图像创建纹理，等等
     */
    virtual void prepareTextureWithRenderSource(void* renderSource);
    
    void* setLUTData(Vec2f lutDstSize, Vec2f leftSrcSize,Vec2f rightSrcSize, int dataSizeInShort, const GLushort* lxIntData, const GLushort* lxMinData, const GLushort* lyIntData, const GLushort* lyMinData, const GLushort* rxIntData, const GLushort* rxMinData, const GLushort* ryIntData, const GLushort* ryMinData);
    void setLUTData(Vec2f lutDstSize, Vec2f leftSrcSize,Vec2f rightSrcSize, const void* lutTextureData);
    
    //    inline GLfloat getFocalLength() {return _glCamera->getZNear();}
    //    inline void setFocalLength(GLfloat focalLength) {_glCamera->setZNear(focalLength);}
    
    void updateSourceTextureIfNecessary();
    
    void prepareGLPrograms();
    
    void prepareGLCanvas(GLint x, GLint y, GLint width, GLint height);
    
    void setGLProgramVariables(GLint x, GLint y, GLint width, GLint height, bool withGyroAdust);
    void drawPrimitives();

    inline GLint getLUTTexture() {return _lutTexture;}

    void setDebugPrimitive(Mesh3DRef mesh, int key);
    GLVAORef getDebugPrimitive(int key);
    
    Vec2f _renderSourceSize;
    
private:
    
    void* _renderSource;
    bool _needRenderNewSource;
    
    float _gyroMatrix[16];
    int _gyroMatrixRank = 0;
    
#ifdef USE_MSAA
    GLuint _msaaFramebuffer;
    GLuint _msaaRenderbuffer;
    GLuint _msaaDepthbuffer;
    
    bool   _supportDiscardFramebuffer;
#endif
    GLint _srcTextureL;
    GLint _srcTextureR;
    GLenum _srcTextureTarget;
    bool   _separateSourceTexture;

    GLint _capsTexture;
    GLenum _capsTextureTarget;

    Vec2f _lutDstSize;
    Vec2f _lutSrcSizeL, _lutSrcSizeR;
    
    GLint _yuvTexturesL[3];
    GLint _yuvTexturesR[3];

    bool _drawCaps;

    MadvGLProgramRef _currentGLProgram = NULL;
    MadvGLProgramRef* _glPrograms = NULL;
    
    bool _enableDebug = false;
    GLProgramRef _debugGLProgram = NULL;
    std::map<int, GLVAORef> _debugVAOs;
    
#ifdef DRAW_GRID_SPHERE
    GLint _uniGridColors;
    GLint _uniLongitudeFragments;
    GLint _uniLatitudeFragments;
#endif
    
    bool _flipY;
    
    GLCameraRef _glCamera = NULL;
    
    Mesh3DRef _quadMesh = NULL;
    Mesh3DRef _sphereMesh = NULL;
    Mesh3DRef _capsMesh = NULL;

    GLVAORef _quadVAO = NULL;
    GLVAORef _sphereVAO = NULL;

    GLVAORef _currentVAO = NULL;
    GLVAORef _capsVAO = NULL;

    GLint _lutTexture = -1;

    bool _isYUVColorSpace;

    kmMat4 _textureMatrix;

    int _currentDisplayMode;
    bool _isPrevDisplayModeLittlePlanet = false;
    
    pthread_mutex_t _mutex;
};

typedef AutoRef<MadvGLRenderer> MadvGLRendererRef;

#endif //MadvGLRenderer_hpp
