//
//  CycordAudioRecorder.h
//  ClumsyCopter
//
//  Created by FutureBoy on 12/24/14.
//
//

#ifndef ClumsyCopter_CycordAudioRecorder_h
#define ClumsyCopter_CycordAudioRecorder_h

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AudioComponent.h>
#import <AudioToolBox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

//#import "AEAudioController.h"
//#import "AEBlockAudioReceiver.h"
//#import "AERecorder.h"

@interface CycordAudioRecorder : NSObject
{
    ExtAudioFileRef _audioFileRef;
    AudioStreamBasicDescription _audioFormat;
    AudioComponentInstance _audioUnit;
    
//    AEAudioController* _aeController;
//    AERecorder* _aeRecorder;
}

@property (nonatomic, assign) AudioComponentInstance audioUnit;

+ (CycordAudioRecorder*) sharedInstance;

- (void) startRecording;

- (void) stopRecording;

@end

#endif
