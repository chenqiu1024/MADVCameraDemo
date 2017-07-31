//
//  CycordVideoRecorderDelegate.h
//  ClumsyCopter
//
//  Created by FutureBoy on 12/22/14.
//
//

#ifndef ClumsyCopter_CycordVideoRecorderDelegate_h
#define ClumsyCopter_CycordVideoRecorderDelegate_h

#import <Foundation/Foundation.h>

@protocol CycordVideoRecorderDelegate <NSObject>

@optional

- (void) cycordVideoRecorderDidRenderOneFrame:(int)elapsedMillseconds;

- (void) cycordVideoRecorderDidRecordOneFrame:(int)recordedMillseconds;

- (void) cycordVideoRecorderFailedWhileRecording:(NSError*)error;

@end

#endif
