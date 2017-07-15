//
//  EXIFParser.h
//  Madv360_v1
//
//  Created by QiuDong on 2017/1/17.
//  Copyright © 2017年 Cyllenge. All rights reserved.
//

#ifndef EXIFParser_h
#define EXIFParser_h

#include <stdio.h>
#include <iostream>
#include <stdbool.h>
#ifdef TARGET_OS_IOS
#import <Foundation/Foundation.h>
#endif
#include <stdint.h>
//#define EXV_HAVE_STDINT_H
#include "exiv2/include/exiv2.hpp"

#define EXIF_PILOT 0xFF
#define EXIF_MARKER 0xE1

#define TAG_SUB_TIFF 0x8769
#define TAG_GYRO_DATA 0x9286
#define TAG_SCENE_TYPE 0xA301
#define TAG_IMAGE_MAKE 0x010f
#define TAG_IMAGE_MODEL 0x0110
#define TAG_FILE_SOURCE 0xa300

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct {
        uint16_t length;
        uint8_t reserved[6];
        uint8_t endian[2];
        uint8_t TIFF_ID[2];
        uint8_t TIFF_offset[4];
    } ExifHeaderRaw;
    
    typedef struct {
        uint8_t tag[2];
        uint8_t type[2];
        uint8_t length[4];
        uint8_t valueOrOffset[4];
    } IFDEntryRaw;
    
    typedef struct {
        int length;
        bool isBigEndian;
        int TIFF_ID;
        int TIFF_offset;
    } ExifHeader;
    
    typedef struct {
        int tag;
        int type;
        int length;
        union {
            uint32_t value;
            uint8_t* valueData;
        };
    } IFDEntry;
    
    typedef struct {
        int numberOfEntries;
        IFDEntry* entries;
    } IFDEntryList;
    
    typedef struct {
        int gyroMatrixBytes;
        int sceneType;
        bool withEmbeddedLUT;
    } MadvEXIFExtension;
    
    bool EXIFHeaderReadFromFile(ExifHeader* outExifHeader, IFDEntryList* outEntryList, IFDEntryList* outSubEntryList, const char* jpegPath);

//    int readIFDEntryList(IFDEntryList* outEntryList, const char* jpegPath);
    
    void IFDEntryListPrint(IFDEntryList* entryList);
    void IFDEntryPrint(IFDEntry* entry);
    
    void IFDEntryRelease(IFDEntry* entry);
    
    bool IFDEntryListInit(IFDEntryList* entryList);
    void IFDEntryListRelease(IFDEntryList* entryList);

    MadvEXIFExtension readMadvEXIFExtensionFromJPEG(float* outMatrixData, const char* jpegPath);
    int readGyroDataFromJPEG(float* outMatrixData, const char* jpegPath);
    int readSceneTypeFromJPEG(const char* jpegPath);
    
    int readExtensionFromFile(void** pOutData, const char* filePath);
    
    long readLUTOffsetInJPEG(const char* jpegPath);
    
    void writeExtensionToFile(const char* filePath, const void* data, int32_t length);
    
    int exifPrint(const char* imagePath, std::ostream& output);
    
    void copyEXIFData(const char* destImagePath, const char* sourceImagePath);
    
    bool setXmpGPanoPacket(const char* imagePath);
    
#ifdef __cplusplus
}
#endif

    Exiv2::Image::AutoPtr createExivImage(const char* sourceImagePath);
    void copyEXIFDataFromExivImage(const char* destImagePath, Exiv2::Image::AutoPtr sourceImage);

#endif /* EXIFParser_h */
