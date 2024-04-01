//
//  FLYConnectModel.m
//  FLYKit
//
//  Created by fly on 2023/8/8.
//

#import "FLYConnectModel.h"

@implementation FLYConnectModel


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


