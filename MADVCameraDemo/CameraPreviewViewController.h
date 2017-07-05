//
//  FirstViewController.h
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KxMovieViewController.h"

@interface CameraPreviewViewController : KxMovieViewController

- (IBAction)connectButtonClicked:(id)sender;

- (IBAction)shootButtonTouchDown:(id)sender;

- (IBAction)shootButtonTouchUp:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton* connectButton;

@property (nonatomic, strong) IBOutlet UIButton* shootButton;

@end

