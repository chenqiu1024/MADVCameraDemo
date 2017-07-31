

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface KDGoalBarPercentLayer : CALayer

@property (nonatomic) CGFloat percent;
@property(nonatomic,assign)int innerRadius;
@property(nonatomic,assign)int outerRadius;
@property(nonatomic,strong) UIColor* rightColor;
@property(nonatomic,strong) UIColor* leftColor;
@end
