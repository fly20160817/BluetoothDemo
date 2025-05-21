//
//  FLYBluetoothManager.h
//  FLYKit
//
//  Created by fly on 2023/7/24.
//



/**************************************************************
 
 1.本类支持连接多个蓝牙设备，如果连接了多个设备，代理的回调里记得判断是哪个设备的回调(根据peripheral的name或者subName来区分)。
  
 2.CBPeripheral+FLYExtension 分类给 CBPeripheral 增加了subName属性，如果是靠广播里的某个值连接的，subName会保存广播里的这个值。
 
 3.本类是单利，单利是一对多的，回调按理应该使用通知的方式，但通知传参和取参太麻烦，使用起来也不方便。所以这里使用了代理，更加灵活和方便。
 
 4.代理是一对一的，可能多个地方使用了本单利，多次设置代理会覆盖，导致只有最后一次设置的地方才有效。
   所以本单例类中实现了一对多的代理，即一个单例类可以有多个代理对象。使用数组来管理多个代理对象，并在需要时遍历通知所有代理对象。
 
 
 ❗️❗️❗️如果连接了多个设备，一定要在代理的回调里判断是哪个设备的回调。
      (比如连接成功的代理回调了，不要想当然的以为连接成功了，这可能是其他设备连接成功的回调)
  
 **************************************************************/


 
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "CBPeripheral+FLYExtension.h"

NS_ASSUME_NONNULL_BEGIN

@class FLYBluetoothManager;

@protocol FLYBluetoothManagerDelegate <NSObject>

@optional

/** 蓝牙状态变化的代理 */
- (void)bluetoothManagerDidUpdateState:(CBManagerState)state;

/** 扫描到外围设备 (如果页面上不需要展示设备列表，此代理外界可以不实现，直接使用扫描并连接的方法) */
- (void)bluetoothManager:(FLYBluetoothManager *)manager didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI;

/** 连接外设中 */
-(void)bluetoothManager:(FLYBluetoothManager *)manager connectingPeripheral:(CBPeripheral *)peripheral;

/** 连接外设成功 */
-(void)bluetoothManager:(FLYBluetoothManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral;

/** 连接外设失败 */
- (void)bluetoothManager:(FLYBluetoothManager *)manager didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;

/** 断开外设连接 */
- (void)bluetoothManager:(FLYBluetoothManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error;

/** 扫描外围设备超时 (在规定时间内，没有扫描到指定设备时回调)(只有使用扫描并连接这个方法才会回调，因为只有这个方法指定了扫描的设备) */
- (void)bluetoothManager:(FLYBluetoothManager *)central didTimeoutForDeviceName:(NSString *)deviceName;


                    
/** 扫描到服务时的回调 (内部会自动扫描特征。如果没有特殊需求，外界不需要实现此代理) */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error;

/** 扫描到特征时的回调 (内部会开启特征值的通知。如果没有特殊需求，外界不需要实现此代理)(如果需要关闭通知，外界实现此代理，在代理中关闭即可) */
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error;

/** 特征里的值更新时回调 */
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error;

/** 写入数据后的回调 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error;

/** 通知状态发生变化时回调 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error;

@end


@interface FLYBluetoothManager : NSObject

// 蓝牙状态
@property(nonatomic, assign, readonly) CBManagerState state;

// 意外断开时，是否重连 (默认YES)
@property(nonatomic, assign) BOOL reconnect;



+ (instancetype)sharedManager;


/// 添加代理
- (void)addDelegate:(id<FLYBluetoothManagerDelegate>)delegate;

/// 移除代理 (内部使用了 NSHashTable 来存储代理，当外界的代理对象销毁时，会自动移除代理。所以不需要手动调用此方法，如果需要提前结束代理，才需要手动调用)
- (void)removeDelegate:(id<FLYBluetoothManagerDelegate>)delegate;


/// 扫描并连接设备
/// - Parameters:
///   - name: 需要连接的 设备名字 或 广播里的某个值
///   - second: 超时时间 (设置为0时，则永不超时)(超时后会停止扫描)
- (void)scanAndConnect:(NSString *)name timeout:(NSInteger)second;


/// 开始扫描周边设备
- (void)startScan;

/// 停止扫描周边设备
- (void)stopScan;

/// 连接外围设备 (调用此方法后，不用手动调用停止扫描。内部会在合适的地方自动调用停止扫描)
/// - Parameters:
///   - peripheral: 外设对象
- (void)connectPeripheral:(CBPeripheral *)peripheral;

/// 断开外围设备 (如果此设备还未连接上(还在扫描中)，执行此方法就不会再扫描连接它了)
- (void)disconnectPeripheral:(NSString *)deviceName;

/// 设备是否已连接
- (BOOL)isConnected:(NSString *)deviceName;

/// 读取特征的值
/// - Parameters:
///   - deviceName: 外设名称 (因为支持同时连接多个蓝牙设备，所以要指定读取哪个设备)
///   - characteristicUUID: 特征的UUID
- (void)readWithDeviceName:(NSString *)deviceName characteristicUUID:(NSString *)characteristicUUID;

/// 往特征里写入数据
/// - Parameters:
///   - deviceName: 外设名称 (因为支持同时连接多个蓝牙设备，所以要指定写入哪个设备)
///   - data: 数据
///   - characteristicUUID: 特征的UUID
- (void)writeWithDeviceName:(NSString *)deviceName data:(NSData *)data characteristicUUID:(NSString *)characteristicUUID;

/// 开启/关闭特征值的通知
/// - Parameters:
///   - enabled: YES 开启   NO 关闭
///   - deviceName: 外设名称
///   - characteristicUUID: 特征的UUID
- (void)setNotifyValue:(BOOL)enabled forDeviceName:(NSString *)deviceName characteristicUUID:(NSString *)characteristicUUID;

@end


NS_ASSUME_NONNULL_END


