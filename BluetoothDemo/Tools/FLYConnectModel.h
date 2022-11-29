//
//  FLYConnectModel.h
//  BluetoothDemo
//
//  Created by fly on 2022/11/9.
//

/*
 因为支持同时连接多个外设，所以很多的连接数据都保存连接模型里了。
 */

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLYConnectModel : NSObject

// 保存扫描并连接的name
@property (nonatomic, strong) NSString * connectName;

// 外设对象
@property(nonatomic, strong) CBPeripheral * peripheral;

// 别名 (有时候传进来需要连接的name，并不是外设的name，而是外设广播里的某个值(比如Mac地址)，所以我们增加一个属性，来保存广播里的这个值)
@property (nonatomic, strong) NSString * subName;

//连接成功的回调
@property (nonatomic, copy) void(^connectSuccessBlock)(CBPeripheral *peripheral);

//连接失败的回调
@property (nonatomic, copy) void(^connectFailureBlock)(NSError *error);


@end

NS_ASSUME_NONNULL_END
