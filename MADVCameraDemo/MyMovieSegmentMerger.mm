#import "MyMovieSegmentMerger.h"

#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAudioSession.h>

@interface MyMovieSegmentMerger()
@end

@implementation MyMovieSegmentMerger

/**
 *  多个视频合成为一个视频输出到指定路径,注意区分是否3D视频
 *
 *  @param tArray       视频文件NSURL地址
 *  @param storePath    沙盒目录下的文件夹
 *  @param storeName    合成的文件名字
 *  @param tbool        是否3D视频,YES表示是3D视频
 *  @param successBlock 成功block
 *  @param failureBlcok 失败block
 */
-(void)mergeVideoToOneVideo:(NSArray *)tArray toStorePath:(NSString *)storePath WithStoreName:(NSString *)storeName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
{
    AVMutableComposition *mixComposition = [self mergeVideostoOnevideo:tArray];
    NSURL *outputFileUrl = [self joinStorePaht:storePath togetherStoreName:storeName];
    [self storeAVMutableComposition:mixComposition withStoreUrl:outputFileUrl andVideoUrl:[tArray objectAtIndex:0] WihtName:storeName andIf3D:tbool success:successBlock failure:failureBlcok];
}
-(void)mergeVideoToOneVideo:(NSArray *)tArray intoFile:(NSString *)intoFile andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
{
    AVMutableComposition *mixComposition = [self mergeVideostoOnevideo:tArray];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:intoFile];
    
    [self storeAVMutableComposition:mixComposition withStoreUrl:outputFileUrl andVideoUrl:[tArray objectAtIndex:0] WihtName:[intoFile lastPathComponent] andIf3D:tbool success:successBlock failure:failureBlcok];
}
/**
 *  多个视频合成为一个
 *
 *  @param array 多个视频的NSURL地址
 *  @param timeToCutFromEndInSec 每段视频最后部分要裁剪的时间长度
 *
 *  @return 返回AVMutableComposition
 */
-(AVMutableComposition *)mergeVideostoOnevideo:(NSArray*)array timeToCutFromEndInSec:(float)timeToCutFromEndInSec
{
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    Float64 video_tmpDuration =0.0f;
    Float64 audio_tmpDuration =0.0f;

    for (NSInteger i=0; i<array.count; i++)
    {
        NSURL*    video_inputFileUrl = [NSURL fileURLWithPath:array[i]];
        AVURLAsset *videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
        
        //CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
        CMTime newDurationVideo;
        if (videoAsset.duration.timescale != 0)
            newDurationVideo = CMTimeMakeWithSeconds(videoAsset.duration.value/videoAsset.duration.timescale - timeToCutFromEndInSec,
                                                     videoAsset.duration.timescale);
        else
            newDurationVideo = CMTimeMakeWithSeconds(videoAsset.duration.value - timeToCutFromEndInSec,
                                                     videoAsset.duration.timescale);
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,newDurationVideo);
        
        /**
         *  依次加入每个asset
         *
         *  @param TimeRange 加入的asset持续时间
         *  @param Track     加入的asset类型,这里都是video
         *  @param Time      从哪个时间点加入asset,这里用了CMTime下面的CMTimeMakeWithSeconds(tmpDuration, 0),timesacle为0
         *
         */
        NSError *error;
        NSArray* videoTracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        BOOL tbool = [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[videoTracks objectAtIndex:0] atTime:kCMTimeInvalid error:&error];//CMTimeMakeWithSeconds(video_tmpDuration, 0) error:&error];

        video_tmpDuration += CMTimeGetSeconds(video_timeRange.duration);

        NSURL* audio_inputFileUrl = [NSURL fileURLWithPath:array[i]];

        AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
        //CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
        CMTime newDurationAudio;
        if (audioAsset.duration.timescale != 0)
            newDurationAudio = CMTimeMakeWithSeconds(audioAsset.duration.value/audioAsset.duration.timescale - timeToCutFromEndInSec,
                                                     audioAsset.duration.timescale);
        else
            newDurationAudio = CMTimeMakeWithSeconds(audioAsset.duration.value - timeToCutFromEndInSec,
                                                     audioAsset.duration.timescale);
        CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero,newDurationAudio);

        [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeInvalid error:&error];//]CMTimeMakeWithSeconds(video_tmpDuration, 0) error:nil];
        
        audio_tmpDuration += CMTimeGetSeconds(audio_timeRange.duration);
    }
    return mixComposition;
}
/**
 *  拼接url地址
 *
 *  @param sPath 沙盒文件夹名
 *  @param sName 文件名称
 *
 *  @return 返回拼接好的url地址
 */
-(NSURL *)joinStorePaht:(NSString *)sPath togetherStoreName:(NSString *)sName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *storePath = [documentPath stringByAppendingPathComponent:sPath];
    BOOL isExist = [fileManager fileExistsAtPath:storePath];
    if(!isExist){
        [fileManager createDirectoryAtPath:storePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *realName = [NSString stringWithFormat:@"%@.mp4", sName];
    storePath = [storePath stringByAppendingPathComponent:realName];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:storePath];
    return outputFileUrl;
    

}
/**
 *  存储合成的视频
 *
 *  @param mixComposition mixComposition参数
 *  @param storeUrl       存储的路径
 *  @param successBlock   successBlock
 *  @param failureBlcok   failureBlcok
 */
-(void)storeAVMutableComposition:(AVMutableComposition*)mixComposition withStoreUrl:(NSURL *)storeUrl andVideoUrl:(NSURL *)videoUrl WihtName:(NSString *)aName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
{
    __weak typeof(self) welf = self;
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    _assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    _assetExport.outputURL = storeUrl;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //在系统相册存储一份
            UISaveVideoAtPathToSavedPhotosAlbum([storeUrl path], nil, nil, nil);
            //            在本地沙盒中存储一份,存储成功返回YES,如果不想存到沙盒,直接返回调用<span style="font-family: Arial, Helvetica, sans-serif;">successBlock();</span>
            //                        BOOL successful = [welf.photoStore storeVideoImageScale:videoUrl WihtName:aName andIf3D:tbool];
            //                        dispatch_async(dispatch_get_main_queue(), ^{
            //                            if (successful) {
            //                                successBlock();
            //                            }else
            //                            {
            //                                failureBlcok();
            //                            }
            //                        });
            //successBlock();
        });
    }];
}

@end


