//
//  FLYBluetoothHandler.h
//  FLYKit
//
//  Created by fly on 2023/7/25.
//


/**************************************************************
 
 本类对 FLYBluetoothManager 进行了封装，外界可以直接进行读取和写入操作。
 
 蓝牙状态判断、扫描设备、连接设备、扫描服务、扫描特征，全部都在内部实现了，外界无需过问。如果中间哪一步报错了，会在failure回调里返回错误原因，外界可以根据error的Code进行处理或弹窗提示。(蓝牙没开、授权没开，这两种错误内部进行了弹窗，如果样式不符合需求，可以通过showAlert属性关闭弹窗，外界重新写弹窗即可)
 
 断开连接需要使用FLYBluetoothManager类进行操作。
 如果一进入页面，就需要立马连接，需要使用FLYBluetoothManager类进行操作。
 
 **************************************************************/



#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "FLYBluetoothManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLYBluetoothHandler : NSObject

typedef NS_ENUM(NSInteger, FLYBluetoothErrorCode)
{
    FLYBluetoothErrorCodePoweredOff = 1,        //蓝牙关闭
    FLYBluetoothErrorCodeUnauthorized = 2,      //蓝牙权限被禁
    FLYBluetoothErrorCodeUnsupported = 3,       //蓝牙硬件损坏
    FLYBluetoothErrorCodeTimeout = 4,           //扫描外设超时 (没扫描到)
    FLYBluetoothErrorCodeConnect = 5,           //连接外设失败
    FLYBluetoothErrorCodeDisconnect = 6,        //意外断开连接
    FLYBluetoothErrorCodeWrite = 7,             //写入数据报错
    FLYBluetoothErrorCodeRead = 8,              //读取数据报错
    FLYBluetoothErrorCodeCharacteristicUUID = 9,//未找到指定特征
};

typedef NS_ENUM(NSInteger, FLYBluetoothProgress) {
    FLYBluetoothProgressScanning = 1,       //扫描外设中
    FLYBluetoothProgressConnecting = 2,     //连接外设中
    FLYBluetoothProgressConnected = 3,      //连接成功
    FLYBluetoothProgressDisconnected = 4,   //断开连接
};


typedef void(^BLESuccessBlock)(NSData * _Nullable data);
typedef void(^BLEFailureBlock)(NSError * error);
typedef void(^BLEProgressBlock)(FLYBluetoothProgress progress);
// 根据peripheral的name或者subName属性来判断是哪个设备的回调，然后根据 characteristic.UUID.UUIDString 来区分是哪个特征的数据，数据在 characteristic.value 里面。
typedef void(^BLEUpdateValueBlock)(CBPeripheral * peripheral, CBCharacteristic * characteristic, NSError * error);

// 蓝牙状态异常时，是否显示提示弹窗，默认YES (系统的弹窗样式，如果要修改样式，就把这个属性设置为NO，然后外界在失败的回调里判断code，自己写弹窗。)
@property (nonatomic, assign, getter=isShowAlert) BOOL showAlert;


+ (instancetype)sharedHandler;


/// 往特征里写入数据
/// - Parameters:
///   - name: 设备名字 或 广播里的某个值
///   - services: 需要扫描的服务和特征 (传nil则是扫描所以服务特征)
///   - data: 数据
///   - serviceUUID: 服务的UUID
///   - characteristicUUID: 特征的UUID
///   - success: 成功的回调
///   - failure: 失败的回调
///   - progress: 进度 (扫描中、连接中、连接成功、断开连接)
- (void)bluetoothWriteWithDeviceName:(NSString *)name services:(nullable NSArray<FLYService *> *)services data:(NSData *)data serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID success:(nullable void (^)(void))success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress;


/// 读取特征的值
/// - Parameters:
///   - name: 设备名字 或 Mac地址 (如果是用Mac，需要蓝牙设备把Mac地址放到广播中)
///   - services: 需要扫描的服务和特征 (传nil则是扫描所以服务特征)
///   - serviceUUID: 服务的UUID
///   - characteristicUUID: 特征的UUID
///   - success: 成功的回调
///   - failure: 失败的回调
///   - progress: 进度 (扫描中、连接中、连接成功、断开连接)
- (void)bluetoothReadWithDeviceName:(NSString *)name services:(nullable NSArray<FLYService *> *)services serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID success:(nullable BLESuccessBlock)success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress;


/// 添加一个特征值更新的回调
/// - Parameters:
///   - owner: 回调绑定的对象（通常传 self，即调用者本身。由于本类为单例，添加回调后无法主动判断何时移除，因此通过绑定 owner 的生命周期，在 owner 释放后自动移除对应回调，避免回调在对象已销毁后仍被触发）
///   - callback: 特征值更新时触发的回调
- (void)addCharacteristicValueUpdateCallbackWithOwner:(id)owner callback:(BLEUpdateValueBlock)callback;


@end


NS_ASSUME_NONNULL_END

