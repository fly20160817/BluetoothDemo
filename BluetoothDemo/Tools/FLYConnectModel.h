//
//  FLYConnectModel.h
//  FLYKit
//
//  Created by fly on 2023/8/8.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLYConnectModel : NSObject

/// 保存扫描并连接的name
@property (nonatomic, strong) NSString * connectName;

/// 外设对象
@property(nonatomic, strong) CBPeripheral * peripheral;

/// 倒计时的秒数
@property (nonatomic, assign) NSInteger second;

/// 用来做扫描超时的计时器  (加上nullable，可以避免self.timer = nil;的时候有警告)
@property (nonatomic, strong, nullable) NSTimer * timer;

/// 计时器是否已打开
@property (nonatomic, assign) BOOL isOpenTimer;

/// 倒计时归0的回调
@property (nonatomic, copy) void(^timeoutBlock)(FLYConnectModel * connectModel);



//打开计时器
- (void)startTimer;

//关闭计时器
- (void)stopTimer;


@end

NS_ASSUME_NONNULL_END


