//
//  FLYBluetoothManager.h
//  FLYKit
//
//  Created by fly on 2019/12/11.
//  Copyright © 2019 fly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


NS_ASSUME_NONNULL_BEGIN

@class FLYBluetoothManager;

@protocol FLYBluetoothManagerDelegate <NSObject>

@optional

/** 蓝牙状态改变了 */
- (void)bluetoothManager:(FLYBluetoothManager *)manager didUpdateState:(CBManagerState)state;

/** 扫描到外围设备 */
- (void)bluetoothManager:(FLYBluetoothManager *)manager didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI;

/** 连接外设成功 */
-(void)bluetoothManager:(FLYBluetoothManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral;

/** 断开外设连接 */
- (void)bluetoothManager:(FLYBluetoothManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;



/** 扫描到服务时的回调 */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error;

/** 扫描到特征时的回调 */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error;

/** 读取数据后的回调 */
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;

/** 写入数据后的回调 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;

@end

@interface FLYBluetoothManager : NSObject

@property (nonatomic, weak) id<FLYBluetoothManagerDelegate> delegate;
/// 蓝牙状态
@property (nonatomic, assign, readonly) CBManagerState state;


+ (instancetype)sharedManager;


/// 扫描并连接设备 (连接成功后自动停止扫描)
/// - Parameter name: 需要连接的 设备名字 或 Mac地址 (如果是用Mac，需要蓝牙设备把Mac地址放到广播中)
- (void)scanAndConnect:(NSString *)name;

/// 开始扫描周边设备
- (void)startScan;

/// 停止扫描周边设备
- (void)stopScan;


/// 连接外围设备
/// - Parameter peripheral: 设备对象
- (void)connectPeripheral:(CBPeripheral *)peripheral;

/// 断开外围设备
/// - Parameter peripheral: 设备对象  (FLYBluetoothManager支持同时连接多个蓝牙设备，可以指定断开某个设备。如果传nil，则断开的是最后一个连接的蓝牙设备)
- (void)cancelPeripheralConnection:(nullable CBPeripheral *)peripheral;


/// 读取数据
/// - Parameters:
///   - peripheral: 外设 
///   - characteristicUUID: 特征的UUID
- (void)readDataWithPeripheral:(nullable CBPeripheral *)peripheral characteristicUUID:(NSString *)characteristicUUID;

/// 写入数据
/// - Parameters:
///   - data: 数据
///   - peripheral: 外设
///   - characteristicUUID: 特征的UUID
- (void)writeData:(NSData *)data peripheral:(nullable CBPeripheral *)peripheral characteristicUUID:(NSString *)characteristicUUID;


/// 16进制字符串 转 Data
/// - Parameter hexString: 16进制字符串
+ (NSData *)convertHexStringToData:(NSString *)hexString;

/// Data 转 16进制字符串
/// - Parameter data: data数据
+ (NSString *)convertDataToHexString:(NSData *)data;


@end

NS_ASSUME_NONNULL_END
