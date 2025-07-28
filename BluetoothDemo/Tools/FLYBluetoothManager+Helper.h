//
//  FLYBluetoothManager+Helper.h
//  BluetoothDemo
//
//  Created by fly on 2025/7/28.
//

#import "FLYBluetoothManager.h"
#import "FLYConnectModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLYBluetoothManager (Helper)

/// 遍历所有代理对象，并执行传入的回调 block。
- (void)enumerateDelegatesUsingBlock:(void (^)(id<FLYBluetoothManagerDelegate> delegate))block;

/// 根据 peripheral ，从数组中找到指定的 model
- (FLYConnectModel *)getConnectModelForPeripheral:(CBPeripheral *)peripheral;

/// 根据 deviceName ，从数组中找到指定的 model
- (FLYConnectModel *)getConnectModelForDeviceName:(NSString *)deviceName;

/// 获取指定的特征
- (CBCharacteristic *)getCharacteristicWithPeripheral:(CBPeripheral *)peripheral serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID;

/// 数组里是否存在还未开始连接的设备
- (BOOL)isUnconnected;

/// 从服务数组中提取 serviceUUID 字符串并转换为 CBUUID 数组
- (NSArray<CBUUID *> *)extractServiceUUIDsFromServices:(NSArray<FLYService *> *)services;

/// 从指定服务中提取 characteristicUUID 字符串并转换为 CBUUID 数组
- (NSArray<CBUUID *> *)extractCharacteristicUUIDsFromService:(FLYService *)service;

/// 根据 CBService 找到对应的 FLYService
- (FLYService *)findFLYServiceFromPeripheral:(CBPeripheral *)peripheral cbService:(CBService *)service;


@end

NS_ASSUME_NONNULL_END
