//
//  CBPeripheral+FLYExtension.h
//  BluetoothDemo
//
//  Created by fly on 2023/8/3.
//

#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface CBPeripheral (FLYExtension)

/// 别名 (有时候传进来需要连接的name，并不是外设的name，而是外设广播里的某个值(比如Mac地址)，所以我们增加一个属性，来保存广播里的这个值)
@property (nonatomic, strong) NSString * subName;

@end

NS_ASSUME_NONNULL_END
