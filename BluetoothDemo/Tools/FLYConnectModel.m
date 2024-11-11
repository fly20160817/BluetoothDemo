//
//  FLYConnectModel.m
//  FLYKit
//
//  Created by fly on 2023/8/8.
//

#import "FLYConnectModel.h"

@interface FLYConnectModel ()

/// 用来做扫描超时的计时器  (加上nullable，可以避免self.timer = nil;的时候有警告)
@property (nonatomic, strong, nullable) NSTimer * timer;

/// 计时器是否已打开
@property (nonatomic, assign) BOOL isOpenTimer;

@end

@implementation FLYConnectModel

- (void)dealloc
{
    NSLog(@"----------------销毁咯：%@，connectName = %@----------------", self, self.connectName);
}

- (void)countdownClick
{
    _second -= 1;
    
    if( _second == 0 )
    {
        [self stopTimer];
        
        !self.timeoutBlock ?: self.timeoutBlock(self);
    }
}


//打开计时器
- (void)startTimer
{
    self.isOpenTimer = YES;
    
    self.timer.fireDate = [NSDate distantPast];
}

//关闭计时器
- (void)stopTimer
{
    self.isOpenTimer = NO;
    
    [self.timer invalidate];
    self.timer = nil;
}



#pragma mark - setters and getters

-(NSTimer *)timer
{
    if (_timer == nil)
    {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(countdownClick) userInfo:nil repeats:YES];
        _timer.fireDate = [NSDate distantFuture];
    }
    return _timer;
}

@end



