//
//  PrefixHeader.pch
//  MADVCamera
//
//  Created by QiuDong on 2017/7/4.
//  Copyright © 2017年 QiuDong. All rights reserved.
//

#ifndef PrefixHeader_h
#define PrefixHeader_h

#import "ResourceKeys.h"
#import "FGLanguageTool.h"

#import "AMBACommands.h"
//#import <MADVPano/MADVPano.h>
#import "LogManager.h"

///////////////////

#define STRINGIZE0(...) __VA_ARGS__
#define STRINGIZE(...) #__VA_ARGS__
#define STRINGIZE2(...) STRINGIZE(__VA_ARGS__)
#define NSSTRINGIZE(...) @ STRINGIZE2(__VA_ARGS__)

///////////////////

#define MyURLScheme @"madv360"

///!!!For Debug:
//#define DEBUG_GYRO
#define GyroFileName  "Matrix_GYRO_001012AA.txt"
//#define GyroVideoName  "Gyro_001012AA.mp4"
#define GyroVideoName  "MJXJ.MP4"

// Include any system framework and library headers here that should be included in all compilation units.
// You will also need to set the Prefix Header build setting of one or more of your targets to reference this file.
#define ScreenWidth [UIScreen mainScreen].bounds.size.width
#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#define Reachable @"Reachable"
#define REACHABLETYPE @"REACHABLETYPE"
#define REACHABLEWiFi @"REACHABLEWiFi"
#define REACHABLEWWAN @"REACHABLEWWAN"
#define WiFiTOWWAN @"WiFiTOWWAN"
#define SHARESUCCESS @"SHARESUCCESS"
#define XMAPPID @"2882303761517454273"
#define XMREDIRECTURL @"http://api.madv360.com:9999/oauth-xm"

#define MEDIAFAVORSUCCESS @"MEDIAFAVORSUCCESS"

//开放是HTTPS 注释掉是禁用HTTPS
//#define ISATS
#ifdef ISATS
#define HEADURL @"https://api.madv360.com:443/"
#else
#define HEADURL @"http://tapi.madv360.com:9999/"
#endif

#define FAQWEBURL @"http://api.madv360.com:9999/html/help/normal_problem_cn.html"
#define TWFAQWEBURL @"http://hapi.madv360.com:9999/html/help/normal_problem_tw.html"
#define ENFAQWEBURL @"http://oapi.madv360.com:9999/html/help/normal_problem.html"

#define INSTRUCTIONSURL @"http://api.madv360.com:9999/html/help/user_manual_cn.html"
#define TWINSTRUCTIONSURL @"http://hapi.madv360.com:9999/html/help/user_manual_tw.html"
#define ENINSTRUCTIONSURL @"http://oapi.madv360.com:9999/html/help/user_manual.html"
//用户协议
#define USERAGREEMENT @"http://api.madv360.com:9999/html/help/about.html"
#define TWUSERAGREEMENT @"http://hapi.madv360.com:9999/html/help/complex-protocol.html"
#define ENUSERAGREEMENT @"http://oapi.madv360.com:9999/html/help/about_en.html"

#define TWPRIVACYPOLICY @"http://hapi.madv360.com:9999/html/help/complex-secret.html"

#define RGBCOLORA(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]

#define RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

//图库中按日来分
#define PHOTODATEFORMAT @"PHOTODATEFORMAT"

#define ADDTAGSUCCESS @"ADDTAGSUCCESS"

//上传文件
#define APPID @"2882303761517447532"
#define OAUTHAPPID @"2882303761517454273"

#define OAUTHPROVIDER @"XiaoMi"
#define OAUTHMACALGORITHM @"HmacSHA1"

#define UPLOADSUCCESS @"UPLOADSUCCESS"

#define BINDPHONESUCCESS @"BINDPHONESUCCESS"

#define ENTERFOREGROUND @"ENTERFOREGROUND"

#define ENTERBACKGROUND @"ENTERBACKGROUND"

#define ISLOGINTHIRD @"ISLOGINTHIRD"

//开发环境下等于 @"ENVIRONMENT_DEVELOPMENT"  上线等于  @"ENVIRONMENT_USER"
#define MVCAMERACLIENT_ENVIRONMENT @"ENVIRONMENT_USER"
#define ENVIRONMENT_DEVELOPMENT @"ENVIRONMENT_DEVELOPMENT"
#define ENVIRONMENT_USER @"ENVIRONMENT_USER"

#define MRDIAMABAGER_ENVIRONMENT @"ENVIRONMENT_DEVELOPMENT"

#define NETCHANGED @"NETCHANGED"
#define REACHABLECHANGED @"REACHABLECHANGED"

//连接成功
#define CONNECTEDSUCCESS @"CONNECTEDSUCCESS"

//断开连接
#define DISCONNECT @"DISCONNECT"

//设置成功
#define CAMERASETSUCCESS @"CAMERASETSUCCESS"

#define PUBLISHDELETESUCCESS @"PUBLISHDELETESUCCESS"
#define DETAILPUBLISHDELETESUC @"DETAILPUBLISHDELETESUC"

#define MEDIALIBRARYDATEFORMATTER @"MEDIALIBRARYDATEFORMATTER"

#define CAMERAPROTOCOLHEAD @"rtsp://192.168.42.1"

#define DELETELOCALMEDIASUC @"DELETELOCALMEDIASUC"

#define DELETECAMERAMEDIASUC @"DELETECAMERAMEDIASUC"

#define BUGLYAPPID @"7c2d0fb443"

//开发环境下等于 @"ENVIRONMENT_DEVELOPMENT"  上线等于  @"ENVIRONMENT_USER"
#define BUGLY_ENVIRONMENT @"ENVIRONMENT_DEVELOPMENT"
//开发环境下注释掉  上线时开放
//#define ENVIRONMENT_PRODUCT

#ifdef ENVIRONMENT_PRODUCT
#define NSLog BLYLogInfo
#endif

#define LOGINACCOUNTNUMBER @"ORDINARYLOGIN"
#define MILOGIN @"MILOGIN"
#define ORDINARYLOGIN @"ORDINARYLOGIN"

//拍照模式所存的坏境 开发环境下等于 @"ENVIRONMENT_DEVELOPMENT"  内测等于  @"MIBETA_ENVIRONMENT"
#define MODE_ENVIRONMENT @"ENVIRONMENT_DEVELOPMENT"
#define MIBETA_ENVIRONMENT @"MIBETA_ENVIRONMENT"

#define UPLOAD_ERROR @"UPLOAD_ERROR"
#define UPLOAD_SUCCESS @"UPLOAD_SUCCESS"

//#define DEBUG_VIDEO_RENDERING

#define DECODE_FILENAME_EXTEND1080  @"_output1080"

#define DECODE_FILENAME_EXTEND4K @"_output4K"

#define DECODE_FILENAME_EXTENDOTHER @"_output"

#define VIDEO_EXTENSION_NAME @".mp4"

#define CAMERA_FWVER @"CAMERA_FWVER"
#define CAMERA_SERIALID @"CAMERA_SERIALID"
#define REMOTE_FWVER @"REMOTE_FWVER"

#define FIRMWARE_VERSION @"HARD_VERSION"
#define FIRMWARE_FILENAME @"HARD_FILENAME"
#define RC_FIRMWARE_VERSION @"REMOTER_VERSION"
#define RC_FIRMWARE_FILENAME @"REMOTER_FILENAME"
#define FIRMWARE_CANCELDOWNLOADDATE @"FIRMWARE_CANCELDOWNLOADDATE"
#define CANCEL_CAMERA_UPDATE_DATE @"CANCEL_CAMERA_UPDATE_DATE"

//新手引导页
#define LINKCAMGUIDE @"LINKCAMGUIDE"

#define SHOTRGUIDE @"SHOTRGUIDE"

#define SHOTSECVIDEORGUIDE @"SHOTSECVIDEORGUIDE"
#define SHOTSECPHOTORGUIDE @"SHOTSECPHOTORGUIDE"

#define DOWNLOADGUIDE @"DOWNLOADGUIDE"

//是否需要导入
#define ISIMPORT

#define VIDEO4KWIDTH 3456

#define VIDEO4KHEIGHT 1728
//是否开启固件升级
#define ISHARDUPDATE 1

//是否测试固件升级
//#define ISTESTHARDUPDATE

#define GYRODATAAVAILABLE @"GYRODATAAVAILABLE"

//#define DEBUGGING_FILTERS

#define USE_CREATETEXTUREWITHJPEG

#define USE_HTTP_DOWNLOADING
//#define DEBUG_HTTP_DOWNLOADING

//#define DEBUG_DISABLE_REALM
#define RELOADLIBRARY @"RELOADLIBRARY"
//wifi开头
#define WIFIHASPREFIX @"SV1-"
#define LASTWIFIHASPREFIX @"MJXJ-"
#define UPDATEHARDDETAIL @"UPDATEHARDDETAIL"
#define ISSHOWBAGE @"ISSHOWBAGE"
#define CONNECTSUC @"CONNECTSUC"

//#define DEBUG_UPLOADING

#define DEBUG_VIDEOFRAME_LEAKING

//#define USE_IMAGE_BLENDER
//#define LUT_STITCH_PICTURE

#define USE_REFLATTERNING_MODE

#define RECONNECT_ON_BACK_FOREGROUND

#define VERSION @"v1.3"

#define RLM_DB_VERSION 14

#define SELECTMUSICNAME @"SELECTMUSICNAME"
#define SELECTMUSICNAMECHANGED @"SELECTMUSICNAMECHANGED"

//不打开编辑功能时就注释掉
#define OPENEDIT

#define USERNAME @"USERNAME"

//不打开新的发布时注释掉
#define OPENNEWPUBLISH
#define ENCODING_WITHOUT_MYGLVIEW

#define PUBLISHLOGINSUC @"PUBLISHLOGINSUC"

#define GUIDEDATE @"GUIDEDATE"
#define SPLASH_MEDIA_NAME @"background"

//#define DEBUG_SPLASH_VIDEO
//是否隐藏滤镜
#define HIDEFILTER

//#define ENABLE_OPENGL_DEBUG

//#define PASS_REMOTECTRL_FIRMWARE_CHECK

//是否转4k视频（针对新旧的发布流程）
//#define ENCODER4K

//#define DISABLE_5MIN_FORBIDDEN

#define FACEBOOKSHARE

#define LANGUAGETABLE @"Localizable"

//#define DEBUG_VIDEORECORDER_INTERRUPTED_BY_ERROR

//#define PAUSE_DOWNLOADING_WHILE_CAPTURING

#define ENCODE_VIDEO_WITH_GYRO

//#define OPENALLWEBOSHARE

#define SDCARD_SUREDATE @"SDCARD_SUREDATE"

//#define WAIT_UNTIL_PREVIOUS_MEDIAPLAYERVIEWCONTROLLER_DEALLOC

#define PHOTOALBUM_NAME @"MadV360Export "

#define PHOTOALBUM_SCREENSHOT @"MadV360ScreenShot"

//#define AUDIOSESSION_CATEGORY kAudioSessionCategory_AmbientSound
#define AUDIOSESSION_CATEGORY kAudioSessionCategory_MediaPlayback

#define ISCHANGEINSIDELAN @"ISCHANGEINSIDELAN"

#define LOCATION @"location"

#define LOCASHARE @"LOCASHARE"

#define ISOPENMOBILEGYROSCOPE @"ISOPENMOBILEGYROSCOPE"
#define HARDDOWNLOADSUC @"HARDDOWNLOADSUC"

#define SCREEN_CAPTURE_FILENAME_PREFIX @"ScreenCap_"

#define OPENGPS @"OPENGPS"
//纬度
#define LATITUDE @"LATITUDE"
//经度
#define LONGITUDE @"LONGITUDE"

//海拔
#define ALTITUDE @"ALTITUDE"

#define LASTLOCATIONENABLED @"LASTLOCATIONENABLED"

//#define ISFULLSCREEN

#define DOUYIN_T2 100

#endif /* PrefixHeader_h */
