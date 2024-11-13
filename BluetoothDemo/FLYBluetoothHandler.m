//
//  FLYBluetoothHandler.m
//  FLYKit
//
//  Created by fly on 2023/7/25.
//

#import "FLYBluetoothHandler.h"
#import "UIAlertController+FLYExtension.h"

const NSErrorDomain domain1 = @"蓝牙未打开";
const NSErrorDomain domain2 = @"蓝牙权限被禁";
const NSErrorDomain domain3 = @"蓝牙硬件损坏";
const NSErrorDomain domain4 = @"扫描外设超时 (没扫描到)";
const NSErrorDomain domain5 = @"连接外设失败";
const NSErrorDomain domain6 = @"意外断开连接";
const NSErrorDomain domain7 = @"写入数据报错";
const NSErrorDomain domain8 = @"读取数据报错";


@interface FLYCommand : NSObject

typedef NS_ENUM(NSInteger, FLYCommandType) {
    FLYCommandTypeNone = 0,    // 无 (没有待执行的指令)
    FLYCommandTypeRead = 1,    // 读
    FLYCommandTypeWrite = 2,   // 写
};

@property (nonatomic, strong) NSString * deviceName;
@property (nonatomic, strong) NSString * characteristicUUID;
@property (nonatomic, assign) FLYCommandType commandType;
@property (nonatomic, strong) NSData * data;

@end

@implementation FLYCommand
@end



@interface FLYBluetoothHandler () < FLYBluetoothManagerDelegate >

@property (nonatomic, copy) BLESuccessBlock success;
@property (nonatomic, copy) BLEFailureBlock failure;
@property (nonatomic, copy) BLEProgressBlock progress;
@property (nonatomic, copy) BLEUpdateValueBlock updateValue;

// 存放待执行的蓝牙命令 (外界传命令进来的时候，蓝牙可能还没连接，所以先把蓝牙命令保存，等连接后在执行命令。)
@property (nonatomic, strong) FLYCommand * command;

@end

@implementation FLYBluetoothHandler

+ (instancetype)sharedHandler
{
    static FLYBluetoothHandler * _handler;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _handler = [[FLYBluetoothHandler alloc] init];
    });
    
    return _handler;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[FLYBluetoothManager sharedManager] addDelegate:self];
        //[FLYBluetoothManager sharedManager].reconnect = YES;
        
        self.showAlert = YES;
    }
    return self;
}


/// 往特征里写入数据
- (void)bluetoothWriteWithDeviceName:(NSString *)name data:(NSData *)data characteristicUUID:(NSString *)characteristicUUID success:(void (^)(void))success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress
{
    // 写入成功的block是没有参数的，而self.success是有参数的，赋值会报错，所以需要强转一下。
    self.success = (void (^)(id))success;
    self.failure = failure;
    self.progress = progress;
    
    
    // 如果蓝牙状态不是打开的，手动调一下蓝牙状态的代理，代理里会处理各种状态
    if ( [FLYBluetoothManager sharedManager].state != CBManagerStatePoweredOn && [FLYBluetoothManager sharedManager].state != CBManagerStateUnknown )
    {
        [self bluetoothManagerDidUpdateState:[FLYBluetoothManager sharedManager].state];
        return;
    }
    
    
    // 保存传进来的数据
    FLYCommand * command = [[FLYCommand alloc] init];
    command.deviceName = name;
    command.characteristicUUID = characteristicUUID;
    command.data = data;
    command.commandType = FLYCommandTypeWrite;
    self.command = command;
    
    
    //判断传进来的设备，是否已连接
    if ( [[FLYBluetoothManager sharedManager] isConnected:name] )
    {
        // 已连接立马就调用了指令，所以要把 commandType 改成 None
        command.commandType = FLYCommandTypeNone;
        
        [[FLYBluetoothManager sharedManager] writeWithDeviceName:name data:data characteristicUUID:characteristicUUID];
        return;
    }
    
    
    !self.progress ?: self.progress(FLYBluetoothProgressScanning);
    [[FLYBluetoothManager sharedManager] scanAndConnect:name timeout:60];
    
}


/// 读取特征的值
- (void)bluetoothReadWithDeviceName:(NSString *)name characteristicUUID:(NSString *)characteristicUUID success:(nullable BLESuccessBlock)success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress
{
    self.success = success;
    self.failure = failure;
    self.progress = progress;
    
    // 如果蓝牙状态不是打开的，手动调一下蓝牙状态的代理，代理里会处理各种状态
    if ( [FLYBluetoothManager sharedManager].state != CBManagerStatePoweredOn && [FLYBluetoothManager sharedManager].state != CBManagerStateUnknown )
    {
        [self bluetoothManagerDidUpdateState:[FLYBluetoothManager sharedManager].state];
        return;
    }
    
    
    // 保存传进来的数据
    FLYCommand * command = [[FLYCommand alloc] init];
    command.deviceName = name;
    command.characteristicUUID = characteristicUUID;
    command.commandType = FLYCommandTypeRead;
    self.command = command;
    
    
    //判断传进来的设备，是否已连接
    if ( [[FLYBluetoothManager sharedManager] isConnected:name] )
    {
        // 已连接立马就调用了指令，所以要把 commandType 改成 None
        command.commandType = FLYCommandTypeNone;
        
        // 读取前先把通知给关闭，不然回调里不能区分是读取的回调还是通知的回调。(回调收到数据后会重新打开)
        [[FLYBluetoothManager sharedManager] setNotifyValue:NO forDeviceName:name characteristicUUID:characteristicUUID];
        
        [[FLYBluetoothManager sharedManager] readWithDeviceName:name characteristicUUID:characteristicUUID];
        return;
    }
    
    
    !self.progress ?: self.progress(FLYBluetoothProgressScanning);
    [[FLYBluetoothManager sharedManager] scanAndConnect:name timeout:60];
}


/// 特征里的值更新时回调
- (void)bluetoothDidUpdateValueForCharacteristic:(BLEUpdateValueBlock)updateValue
{
    self.updateValue = updateValue;
}



#pragma mark - FLYBluetoothManagerDelegate

//判断设备的更新状态
- (void)bluetoothManagerDidUpdateState:(CBManagerState)state
{
    switch (state)
    {
        case CBManagerStateUnknown:
            break;
            
        case CBManagerStateResetting:
            break;
            
        case CBManagerStateUnsupported:
        {
            if ( self.isShowAlert )
            {
                UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"您的设备无法使用蓝牙功能" preferredStyle:UIAlertControllerStyleAlert titles:@[@"确定"] alertAction:^(NSInteger index) {}];
                [alertController show];
            }
            
            
            NSError * error = [NSError errorWithDomain:domain3 code:FLYBluetoothErrorCodeUnsupported userInfo:nil];
            !self.failure ?: self.failure(error);
            [self reset];
        }
            break;
            
        case CBManagerStateUnauthorized:
        {
            if ( self.isShowAlert )
            {
                UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"您已关闭蓝牙权限，请打开蓝牙权限" preferredStyle:UIAlertControllerStyleAlert titles:@[@"取消", @"去打开"] alertAction:^(NSInteger index) {
                    if ( index == 1 )
                    {
                        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
                    }
                }];
                [alertController show];
            }
            
            NSError * error = [NSError errorWithDomain:domain2 code:FLYBluetoothErrorCodeUnauthorized userInfo:nil];
            !self.failure ?: self.failure(error);
            [self reset];
        }
            break;
            
        case CBManagerStatePoweredOff:
        {
            if ( self.isShowAlert )
            {
                UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"蓝牙已关闭" message:@"请前往设置中开启蓝牙" preferredStyle:UIAlertControllerStyleAlert titles:@[@"确定"] alertAction:^(NSInteger index) {}];
                [alertController show];
            }
            
            NSError * error = [NSError errorWithDomain:domain1 code:FLYBluetoothErrorCodePoweredOff userInfo:nil];
            !self.failure ?: self.failure(error);
            [self reset];
        }
            break;
            
        case CBManagerStatePoweredOn:
            break;
            
        default:
            break;
    }
}

// 连接外设中
-(void)bluetoothManager:(FLYBluetoothManager *)manager connectingPeripheral:(CBPeripheral *)peripheral
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    
    !self.progress ?: self.progress(FLYBluetoothProgressConnecting);
}

// 连接到外设后调用
-(void)bluetoothManager:(FLYBluetoothManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    !self.progress ?: self.progress(FLYBluetoothProgressConnected);
}

// 连接外设失败
- (void)bluetoothManager:(FLYBluetoothManager *)manager didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    NSError * err = [NSError errorWithDomain:domain5 code:FLYBluetoothErrorCodeConnect userInfo:nil];
    !self.failure ?: self.failure(err);
    [self reset];
}

// 断开连接
-(void)bluetoothManager:(FLYBluetoothManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    
    if ( error )
    {
        NSError * err = [NSError errorWithDomain:domain6 code:FLYBluetoothErrorCodeDisconnect userInfo:nil];
        !self.failure ?: self.failure(err);
        [self reset];
    }
    else
    {
        // 只有正常断开的才执行进度回调，意外断开属于错误，不属于进度。
        !self.progress ?: self.progress(FLYBluetoothProgressDisconnected);
    }
}

// 扫描超时
-(void)bluetoothManagerDidTimeout:(FLYBluetoothManager *)central
{
    if ( self.command.deviceName == nil )
    {
        return;
    }
    
    
    NSError * err = [NSError errorWithDomain:domain4 code:FLYBluetoothErrorCodeTimeout userInfo:nil];
    !self.failure ?: self.failure(err);
    [self reset];
}

// 扫描到特征
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    
    for (CBCharacteristic * characteristic in service.characteristics )
    {
        // 特征具有通知属性，设置特征值的更新通知 （&是位运算中的按位与操作符）
        if (characteristic.properties & CBCharacteristicPropertyNotify)
        {
            // 订阅, 实时接收 (在didUpdateValueForCharacteristic里返回)
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        
        // 如果有未执行的命令，则执行
        if ( [self.command.characteristicUUID isEqualToString:characteristic.UUID.UUIDString] && self.command.commandType != FLYCommandTypeNone )
        {
            if ( self.command.commandType == FLYCommandTypeWrite )
            {
                [[FLYBluetoothManager sharedManager] writeWithDeviceName:self.command.deviceName data:self.command.data characteristicUUID:self.command.characteristicUUID];
            }
            else if ( self.command.commandType == FLYCommandTypeRead )
            {
                // 读取前先把通知给关闭，不然回调里不能区分是读取的回调还是通知的回调。(回调收到数据后会重新打开)
                [[FLYBluetoothManager sharedManager] setNotifyValue:NO forDeviceName:self.command.deviceName characteristicUUID:self.command.characteristicUUID];
                
                [[FLYBluetoothManager sharedManager] readWithDeviceName:self.command.deviceName characteristicUUID:self.command.characteristicUUID];
            }
            
            // 执行完之后把操作类型设置成无
            self.command.commandType = FLYCommandTypeNone;
        }
        
    }

}

/** 读取特征数据 或 订阅的特征值更新 的回调 */
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    /* 通常情况下，通知、读、写操作会使用不同的特征来实现，但也有一些特殊情况下可能会使用同一个特征来实现通知、读、写功能。这主要取决于蓝牙设备的设计和实现。
    
        通过特征的 isNotifying 属性来判断是谁的回调，YES是通知的回调(setNotifyValue:forCharacteristic:)，NO是主动读取的回调(readValueForCharacteristic:)。
        
        如果一个特征开启了通知，再执行读的操作，isNotifying就会不准确，无法判断是读取还是通知的回调。(最好读的特征就别在开通知了，但也有例外，比如某个特征值存储的是电量，开启通知，电量变化会主动通知，但也可以主动去读取一下电量还剩多少。)
     */
    
    
    if( characteristic.isNotifying )
    {
        !self.updateValue ?: self.updateValue(peripheral, characteristic, error);
    }
    else
    {
        if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
        {
            return;
        }
        
        
        // 因为读取前先把通知给关闭，所以这里收到到数据后在给它打开。
        [[FLYBluetoothManager sharedManager] setNotifyValue:YES forDeviceName:self.command.deviceName characteristicUUID:self.command.characteristicUUID];
        
        
        if ( error )
        {
            NSError * err = [NSError errorWithDomain:domain8 code:FLYBluetoothErrorCodeRead userInfo:nil];
            !self.failure ?: self.failure(err);
            [self reset];
        }
        else
        {
            //如果读取的特征开了通知，读取成功不一定在这里返回，也可能在updateValue里返回，所以外界要把写在读取successBlock里的代码，也写到updateValueBlock里。（如果读取的特征不需要开启通知，就给他关咯，省的写两个地方）
            !self.success ?: self.success(characteristic.value);
            [self reset];
        }
    }
}

/** 写入数据后的回调 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( ![self.command.deviceName isEqualToString:peripheral.name] && ![self.command.deviceName isEqualToString:peripheral.subName] )
    {
        return;
    }
    
    
    if ( error )
    {
        NSError * err = [NSError errorWithDomain:domain7 code:FLYBluetoothErrorCodeWrite userInfo:nil];
        !self.failure ?: self.failure(err);
        [self reset];
        return;
    }
    
    !self.success ?: self.success(nil);
    [self reset];
}



#pragma mark - private methods

- (void)reset
{
    // 执行完一个回调后，其他的都要置空。
    // 如果其他地方直接使用了FLYBluetoothManager类操作了当前设备，这里的代理也会跟着回调，如果不置空，这些block又被执行一遍。
    
    self.success = nil;
    self.failure = nil;
    self.progress = nil;
    
    //command置空的原因：比如刚连接上，还没来得及执行指令，就意外断开了，已经执行了failure的回调，若此时重连代码让它重新连接了，发现了未执行的执行，又把指令执行了，这样就即回调了失败，指令又执行成功了。所以置空的时候也要把它给一起置空了。
    self.command = nil;
}


@end


