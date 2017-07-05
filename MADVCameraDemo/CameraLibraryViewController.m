//
//  CameraLibraryViewController.m
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import "CameraLibraryViewController.h"
#import "MVCameraClient.h"
#import "MVMediaManager.h"
#import "AppDelegate.h"
#import "MediaPlayerViewController.h"

static NSString* MVMediaCellIdentifier = @"MVMediaCellIdentifier";
static NSString* MVMediaHeaderIdentifier = @"MVMediaHeaderIdentifier";

@interface MVMediaCell : UICollectionViewCell

@property (nonatomic, strong) IBOutlet UIImageView* imageView;

@property (nonatomic, strong) IBOutlet UILabel* durationLabel;

@property (nonatomic, strong) IBOutlet UILabel* downloadProgressLabel;

@end

@implementation MVMediaCell

@end

@interface MVMediaHeader : UICollectionReusableView

@property (nonatomic, strong) IBOutlet UILabel* titleLabel;

@end

@implementation MVMediaHeader

@end

@interface CameraLibraryViewController () <UICollectionViewDelegate, UICollectionViewDataSource>

@end

@implementation CameraLibraryViewController

#pragma mark    UICollectionViewDataSource & UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [[AppDelegate sharedApplication] numberOfMediasInSection:section];
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MVMediaCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:MVMediaCellIdentifier forIndexPath:indexPath];
    MVMedia* media = [[AppDelegate sharedApplication] mvMediaOfIndexPath:indexPath];
    if (media)
    {
        MediaThummaryResult* thummary = [[MVMediaManager sharedInstance] getMediaThummary:media];
        if (thummary.isMediaInfoAvailable)
        {
            cell.durationLabel.text = [[@(media.videoDuration) stringValue] stringByAppendingString:@"s"];
            if (media.size > 0)
            {
                if (media.downloadedSize >= media.size)
                {
                    cell.downloadProgressLabel.text = @"OK";
                }
                else
                {
                    cell.downloadProgressLabel.text = [NSString stringWithFormat:@"%d%%", (int)(media.downloadedSize * 100 / media.size)];
                }
            }
            else
            {
                cell.downloadProgressLabel.text = @"??%%";
            }
        }
        if (thummary.thumbnail)
        {
            cell.imageView.image = thummary.thumbnail;
        }
    }
    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return [[AppDelegate sharedApplication] numberOfSections];
}

// The view that is returned must be retrieved from a call to -dequeueReusableSupplementaryViewOfKind:withReuseIdentifier:forIndexPath:
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind != UICollectionElementKindSectionHeader)
        return nil;
    
    MVMediaHeader* header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:MVMediaHeaderIdentifier forIndexPath:indexPath];
    NSString* groupName = [[AppDelegate sharedApplication] groupNameOfIndexPath:indexPath];
    header.titleLabel.text = groupName;
    
    return header;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    MVMedia* media = [[AppDelegate sharedApplication] mvMediaOfIndexPath:indexPath];
    if (media && media.mediaType == MVMediaTypeVideo)
    {
        [MediaPlayerViewController showFromViewController:self media:media parameters:nil];
    }
}

- (void) onAddNewMVMedia:(NSNotification*)notification {
    [self.collectionView reloadData];
}

- (void) onRefreshMVMedia:(NSNotification*)notification {
    NSArray<NSIndexPath* >* indexPaths = notification.object;
    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

#pragma mark    Ctor & Dtor

- (void) dealloc {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
}

#pragma mark    UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onAddNewMVMedia:) name:kNotificationAddNewMVMedia object:nil];
    [nc addObserver:self selector:@selector(onRefreshMVMedia:) name:kNotificationRefreshMVMedia object:nil];
    
    [self.collectionView reloadData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
