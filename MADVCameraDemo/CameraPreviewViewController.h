//
//  FirstViewController.h
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MVKxMovieViewController.h"

@interface CameraPreviewViewController : MVKxMovieViewController

- (IBAction)connectButtonClicked:(id)sender;

- (IBAction)shootButtonTouchDown:(id)sender;

- (IBAction)shootButtonTouchUp:(id)sender;

- (IBAction)set15sButtonClicked:(id)sender;
- (IBAction)set30sButtonClicked:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton* connectButton;

@property (nonatomic, strong) IBOutlet UIButton* shootButton;

@property (nonatomic, strong) IBOutlet UILabel* timerLabel;

@property (nonatomic, strong) IBOutlet UILabel* dateLabel;

@end

