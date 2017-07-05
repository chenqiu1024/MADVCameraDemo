//
// Created by admin on 16/8/24.
//

#ifndef APP_ANDROID_IMAGECODEC_H
#define APP_ANDROID_IMAGECODEC_H

/******************************图片数据*********************************/
typedef struct _pic_data
{
    int width, height; /* 尺寸 */
    int bit_depth;  /* 位深 */
    int channels; /* 多少个颜色通道 */
    int flag;   /* 一个标志，表示是否有alpha通道 */

    unsigned char **rgba; /* 图片数组 */
} pic_data;
/**********************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

int decodePNG(const char *filepath, pic_data *out);

int encodePNG(const char* filename, unsigned char* pixels, int w, int h, int bitdepth);

int createTextureFromPNG(const char* pngPath);
    
#ifdef __cplusplus
}
#endif

#endif //APP_ANDROID_IMAGECODEC_H
