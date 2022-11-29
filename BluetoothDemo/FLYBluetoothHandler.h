//
//  FLYBluetoothHandler.h
//  BluetoothDemo
//
//  Created by fly on 2022/10/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLYLockType)
{
    FLYLockTypeLYYSS = 1,     //蓝牙钥匙锁
    FLYLockTypeLYS = 2,       //蓝牙锁
    FLYLockTypeNFC = 3,       //NFC锁
    FLYLockTypeOTG = 4,       //OTG锁
    FLYLockTypeLWJFS = 5,     //联网机房锁
    FLYLockTypeLWJGS = 6,     //联网机柜锁
    FLYLockTypeLYYSLYS = 7,   //蓝牙钥匙蓝牙锁
    FLYLockTypeZNS = 8,       //智能锁
    FLYLockTypeRLMBJ = 9,     //人脸面板机
};

typedef void(^SuccessBlock)(NSString * lockId);
typedef void(^FailureBlock)(NSString * lockId,  NSError * _Nullable error);

@interface FLYBluetoothHandler : NSObject

+ (instancetype)sharedHandler;

- (void)openLock:(NSString *)lockId lockType:(FLYLockType)lockType params:(nullable NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
