//
//  FLYBluetoothHandler.m
//  FLYKit
//
//  Created by fly on 2023/7/25.
//

#import "FLYBluetoothHandler.h"
#import "UIAlertController+FLYExtension.h"
#import "FLYTools.h"

const NSErrorDomain domain1 = @"蓝牙未打开";
const NSErrorDomain domain2 = @"蓝牙权限被禁";
const NSErrorDomain domain3 = @"蓝牙硬件损坏";
const NSErrorDomain domain4 = @"扫描外设超时 (没扫描到)";
const NSErrorDomain domain5 = @"连接外设失败";
const NSErrorDomain domain6 = @"意外断开连接";
const NSErrorDomain domain7 = @"写入数据报错";
const NSErrorDomain domain8 = @"读取数据报错";
const NSErrorDomain domain9 = @"未找到指定特征";


@interface FLYCommand : NSObject

typedef NS_ENUM(NSInteger, FLYCommandType) {
    FLYCommandTypeNone = 0,    // 无 (没有待执行的指令)
    FLYCommandTypeRead = 1,    // 读
    FLYCommandTypeWrite = 2,   // 写
};

@property (nonatomic, strong) NSString * deviceName;
@property (nonatomic, strong, nullable) NSArray<FLYService *> * services;
@property (nonatomic, strong) NSString * serviceUUID;
@property (nonatomic, strong) NSString * characteristicUUID;
@property (nonatomic, assign) FLYCommandType commandType;
@property (nonatomic, strong) NSData * data;

@property (nonatomic, copy) BLESuccessBlock success;
@property (nonatomic, copy) BLEFailureBlock failure;
@property (nonatomic, copy) BLEProgressBlock progress;

@end

@implementation FLYCommand
@end



@interface FLYBluetoothHandler () < FLYBluetoothManagerDelegate >

/// 每个设备的命令队列字典
/// key   = 设备唯一标识（例如设备名、MAC地址等）
/// value = 该设备对应的待执行命令数组
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<FLYCommand *> *> *deviceCommandQueues;

/// 每个设备当前正在执行的命令
/// key   = 设备唯一标识
/// value = 当前正在执行的 FLYCommand（执行完才会取下一条）
@property (nonatomic, strong) NSMutableDictionary<NSString *, FLYCommand *> *deviceCurrentCommands;



/// 保存特征值更新回调的字典
/// 键为回调绑定的 owner
/// 值为对应的回调 block
/// 使用 NSMapTable 实现 owner 释放后，自动移除对应回调
@property (nonatomic, strong) NSMapTable<id, BLEUpdateValueBlock> *ownerToCallbackMap;

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
        
        /*
         NSMapTable 创建方式说明：

         strongToStrongObjectsMapTable
         - key：强引用
         - value：强引用
         - 等价于 NSMutableDictionary 的行为
         - 使用场景：需要手动管理键和值生命周期的映射关系

         weakToStrongObjectsMapTable
         - key：弱引用
         - value：强引用
         - 当 key 被释放后，键值对会自动移除
         - 使用场景：希望 key 不被强持有，并在其释放后自动清理对应关系

         strongToWeakObjectsMapTable
         - key：强引用
         - value：弱引用
         - 当 value 被释放后，键值对会自动移除
         - 使用场景：缓存或引用中心等场景，避免强持有 value 导致循环引用

         weakToWeakObjectsMapTable
         - key：弱引用
         - value：弱引用
         - 当 key 或 value 任一释放后，键值对会自动移除
         - 使用场景：极端轻量的引用场景，避免任何强引用关系
         */
        
        
        // 创建一个键为弱引用、值为强引用的映射表
        self.ownerToCallbackMap = [NSMapTable weakToStrongObjectsMapTable];
        
        self.deviceCommandQueues = [NSMutableDictionary dictionary];
        self.deviceCurrentCommands = [NSMutableDictionary dictionary];
        
        [[FLYBluetoothManager sharedManager] addDelegate:self];
        //[FLYBluetoothManager sharedManager].reconnect = YES;
        
        self.showAlert = YES;
    }
    return self;
}


/// 往特征里写入数据
- (void)bluetoothWriteWithDeviceName:(NSString *)name services:(nullable NSArray<FLYService *> *)services data:(NSData *)data serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID success:(nullable void (^)(void))success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress
{
    // 保存传进来的数据
    FLYCommand * command = [[FLYCommand alloc] init];
    command.deviceName = name;
    command.services = services;
    command.serviceUUID = serviceUUID;
    command.characteristicUUID = characteristicUUID;
    command.data = data;
    command.commandType = FLYCommandTypeWrite;
    // 写入成功的block是没有参数的，而self.success是有参数的，赋值会报错，所以需要强转一下。
    command.success = (void (^)(id))success;
    command.failure = failure;
    command.progress = progress;
   
    
    // 保存指令模型
    NSMutableArray *queue = self.deviceCommandQueues[command.deviceName];
    if (!queue)
    {
        queue = [NSMutableArray array];
        self.deviceCommandQueues[command.deviceName] = queue;
    }
    [queue addObject:command];
    
    
    // 执行命令
    [self executeCommandForDeviceName:command.deviceName];
}

/// 读取特征的值
- (void)bluetoothReadWithDeviceName:(NSString *)name services:(nullable NSArray<FLYService *> *)services serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID success:(nullable BLESuccessBlock)success failure:(nullable BLEFailureBlock)failure progress:(nullable BLEProgressBlock)progress
{
    // 保存传进来的数据
    FLYCommand * command = [[FLYCommand alloc] init];
    command.deviceName = name;
    command.services = services;
    command.serviceUUID = serviceUUID;
    command.characteristicUUID = characteristicUUID;
    command.commandType = FLYCommandTypeRead;
    command.success = success;
    command.failure = failure;
    command.progress = progress;
    
    
    // 保存指令模型
    NSMutableArray *queue = self.deviceCommandQueues[command.deviceName];
    if (!queue)
    {
        queue = [NSMutableArray array];
        self.deviceCommandQueues[command.deviceName] = queue;
    }
    [queue addObject:command];
    
    
    // 执行命令
    [self executeCommandForDeviceName:command.deviceName];
}


/// 添加一个特征值更新的回调
- (void)addCharacteristicValueUpdateCallbackWithOwner:(id)owner callback:(BLEUpdateValueBlock)callback
{
    if (!owner || !callback)
    {
        return;
    }
        
    // 将 owner 和 callback 添加到字典里
    // 用 owner 作为 key，因为 block 本质上是函数指针与捕获变量的组合体，相同代码的 block 其地址也可能不同，作为 key 不安全
    [self.ownerToCallbackMap setObject:callback forKey:owner];
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
                UIAlertController * alertController = [UIAlertController alertControllerWithTitle:LS(@"蓝牙不支持") message:LS(@"您的设备不支持蓝牙功能") preferredStyle:UIAlertControllerStyleAlert titles:@[LS(@"确定")] alertAction:^(NSInteger index) {}];
                [alertController show];
            }
            
            
            // 遍历所有设备当前命令，调用失败回调
            [self.deviceCurrentCommands enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull deviceName, FLYCommand * _Nonnull command, BOOL * _Nonnull stop) {
                
                NSError * error = [NSError errorWithDomain:domain3 code:FLYBluetoothErrorCodeUnsupported userInfo:nil];
                [self handleFailureForDeviceName:deviceName error:error];
            }];
        }
            break;
            
        case CBManagerStateUnauthorized:
        {
            if ( self.isShowAlert )
            {
                UIAlertController * alertController = [UIAlertController alertControllerWithTitle:LS(@"蓝牙权限未开启") message:LS(@"应用未获得蓝牙授权，请前往设置开启。") preferredStyle:UIAlertControllerStyleAlert titles:@[LS(@"取消"), LS(@"前往设置")] alertAction:^(NSInteger index) {
                    if ( index == 1 )
                    {
                        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
                    }
                }];
                [alertController show];
            }
            
            
            // 遍历所有设备当前命令，调用失败回调
            [self.deviceCurrentCommands enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull deviceName, FLYCommand * _Nonnull command, BOOL * _Nonnull stop) {
                
                NSError * error = [NSError errorWithDomain:domain2 code:FLYBluetoothErrorCodeUnauthorized userInfo:nil];
                [self handleFailureForDeviceName:deviceName error:error];
            }];
        }
            break;
            
        case CBManagerStatePoweredOff:
        {
            if ( self.isShowAlert )
            {
                // app在前台的时候才弹窗 (防止用户在后台，把蓝牙关了，此时app已经触发了这个弹窗，然后用户又把蓝牙开了，然后回到app，此时弹窗却出来了，但此时的蓝牙实际上是开的) （上面蓝牙权限的方法为什么不这么写呢，因为开关权限会杀死app，不存在再次回到前台的情况）
                if ( [UIApplication sharedApplication].applicationState == UIApplicationStateActive )
                {
                    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:LS(@"蓝牙已关闭") message:LS(@"请在设置中开启蓝牙") preferredStyle:UIAlertControllerStyleAlert titles:@[LS(@"确定")] alertAction:^(NSInteger index) {}];
                    [alertController show];
                }
            }
            
            
            // 遍历所有设备当前命令，调用失败回调
            [self.deviceCurrentCommands enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull deviceName, FLYCommand * _Nonnull command, BOOL * _Nonnull stop) {
                
                NSError * error = [NSError errorWithDomain:domain1 code:FLYBluetoothErrorCodePoweredOff userInfo:nil];
                [self handleFailureForDeviceName:deviceName error:error];
            }];
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
    // 获取当前正在执行的命令
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if (currentCommand == nil)
    {
        return;
    }
    
    !currentCommand.progress ?: currentCommand.progress(FLYBluetoothProgressConnecting);
}

// 连接到外设后调用
-(void)bluetoothManager:(FLYBluetoothManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 获取当前正在执行的命令
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if (currentCommand == nil)
    {
        return;
    }
    
    !currentCommand.progress ?: currentCommand.progress(FLYBluetoothProgressConnected);
}

// 连接外设失败
- (void)bluetoothManager:(FLYBluetoothManager *)manager didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    // 获取当前正在执行的命令
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if (currentCommand == nil)
    {
        return;
    }
    
    NSError * err = [NSError errorWithDomain:domain5 code:FLYBluetoothErrorCodeConnect userInfo:nil];
    [self handleFailureForDeviceName:currentCommand.deviceName error:err];
}

// 断开连接
-(void)bluetoothManager:(FLYBluetoothManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    // 获取设备对应的命令队列 key，优先用 subName，没有再用 name
    NSString *deviceName = peripheral.subName ?: peripheral.name;
    
    if (deviceName)
    {
        // 从字典里移除对应设备的命令队列
        [self.deviceCommandQueues removeObjectForKey:deviceName];
    }

    
    
    // 如果存在 当前执行的命令，调用完并移除
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if (currentCommand)
    {
        if (error)
        {
            // 意外断开，走失败回调
            NSError *err = [NSError errorWithDomain:domain6 code:FLYBluetoothErrorCodeDisconnect userInfo:nil];
            [self handleFailureForDeviceName:currentCommand.deviceName error:err];
        }
        else
        {
            // 正常断开，执行进度回调
            !currentCommand.progress ?: currentCommand.progress(FLYBluetoothProgressDisconnected);
        }
        
        // 清除当前执行命令
        [self.deviceCurrentCommands removeObjectForKey:currentCommand.deviceName];
    }

}

// 扫描超时
-(void)bluetoothManager:(FLYBluetoothManager *)central didTimeoutForDeviceName:(NSString *)deviceName
{
    FLYCommand * currentCommand = self.deviceCurrentCommands[deviceName];
    
    if ( currentCommand == nil )
    {
        return;
    }
    
    NSError * error = [NSError errorWithDomain:domain4 code:FLYBluetoothErrorCodeTimeout userInfo:nil];
    [self handleFailureForDeviceName:currentCommand.deviceName error:error];
}

// 扫描到特征
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    /*** 这里只是为了找到未执行的命令，然后执行了。订阅通知什么的，在 FLYBluetoothManager 里已经执行过了 ***/
    
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if ( currentCommand == nil )
    {
        return;
    }
    
    
    for (CBCharacteristic * characteristic in service.characteristics )
    {
        // 如果有未执行的命令，则执行
        // 使用 CBUUID 对象比较，避免短 UUID 和完整 UUID 字符串在格式上不一致而导致比较失败
        if ( [[CBUUID UUIDWithString:currentCommand.characteristicUUID] isEqual:characteristic.UUID] && currentCommand.commandType != FLYCommandTypeNone )
        {
            [self sendCommandForDeviceName:currentCommand.deviceName];
        }
    }
    
    
    
    // 特征是否全部扫描完成
    BOOL isScanFinish = YES;
    
    for ( CBService * tempService in peripheral.services)
    {
        // 如果有服务的特征等于nil，说明特征还没扫描完，这个代理还会继续调用
        if ( tempService.characteristics == nil )
        {
            isScanFinish = NO;
        }
    }
    
    // 如果遍历完所有特征，都没找到待执行命令的特征
    if ( isScanFinish == YES && currentCommand.commandType != FLYCommandTypeNone )
    {
        NSError * err = [NSError errorWithDomain:domain9 code:FLYBluetoothErrorCodeCharacteristicUUID userInfo:nil];
        [self handleFailureForDeviceName:currentCommand.deviceName error:err];
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
        // 外界可能会释放掉，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
        NSArray *owners = self.ownerToCallbackMap.keyEnumerator.allObjects;
        
        for (id owner in owners)
        {
            // 根据 owner 获取对应的回调 block
            BLEUpdateValueBlock callback = [self.ownerToCallbackMap objectForKey:owner];
            !callback ?: callback(peripheral, characteristic, error);
        }
        
        return;
    }
    
    
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if ( currentCommand == nil )
    {
        return;
    }
    
    
    // 因为读取前先把通知给关闭，所以这里收到到数据后在给它打开。
    [[FLYBluetoothManager sharedManager] setNotifyValue:YES forDeviceName:currentCommand.deviceName serviceUUID:currentCommand.serviceUUID characteristicUUID:currentCommand.characteristicUUID];
    
    
    if ( error )
    {
        // 10086 代表没找到特征
        NSError * err = [NSError errorWithDomain:error.code == 10086 ? domain9 : domain8 code:error.code == 10086 ? FLYBluetoothErrorCodeCharacteristicUUID : FLYBluetoothErrorCodeRead userInfo:nil];
        [self handleFailureForDeviceName:currentCommand.deviceName error:err];
    }
    else
    {
        //如果读取的特征开了通知，读取成功不一定在这里返回，也可能在updateValue里返回，所以外界要把写在读取successBlock里的代码，也写到updateValueBlock里。（如果读取的特征不需要开启通知，就给他关咯，省的写两个地方）
        [self handleSuccessWithDataForDeviceName:currentCommand.deviceName data:characteristic.value];
    }
    
}

/** 写入数据后的回调 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    FLYCommand *currentCommand = [self currentCommandForPeripheral:peripheral];
    
    if ( currentCommand == nil )
    {
        return;
    }
    
    
    if ( error )
    {
        // 10086 代表没找到特征
        NSError * err = [NSError errorWithDomain:error.code == 10086 ? domain9 : domain7 code:error.code == 10086 ? FLYBluetoothErrorCodeCharacteristicUUID : FLYBluetoothErrorCodeWrite userInfo:nil];
        [self handleFailureForDeviceName:currentCommand.deviceName error:err];
    }
    else
    {
        [self handleSuccessWithDataForDeviceName:currentCommand.deviceName data:nil];
    }
}



#pragma mark - private methods

// 执行命令
- (void)executeCommandForDeviceName:(NSString *)deviceName
{
    if (self.deviceCurrentCommands[deviceName] != nil)
    {
        NSLog(@"设备 %@ 当前已有命令在执行，新命令已加入等待队列", deviceName);
        return;
    }
    
    NSMutableArray<FLYCommand *> *queue = self.deviceCommandQueues[deviceName];
    if (queue.count == 0)
    {
        NSLog(@"设备 %@ 的命令队列为空", deviceName);
        return;
    }
    
    // 取出队列第一个命令，设置为当前命令
    FLYCommand *command = queue.firstObject;
    self.deviceCurrentCommands[deviceName] = command;
    
    
    // 如果蓝牙状态不是打开的，手动调一下蓝牙状态的代理，代理里会处理各种状态
    if ( [FLYBluetoothManager sharedManager].state != CBManagerStatePoweredOn && [FLYBluetoothManager sharedManager].state != CBManagerStateUnknown )
    {
        [self bluetoothManagerDidUpdateState:[FLYBluetoothManager sharedManager].state];
        return;
    }
    
    //判断传进来的设备，是否已连接
    if ( [[FLYBluetoothManager sharedManager] isConnected:deviceName] )
    {
        [self sendCommandForDeviceName:deviceName];
        
        return;
    }
    
    
    !command.progress ?: command.progress(FLYBluetoothProgressScanning);
    [[FLYBluetoothManager sharedManager] scanAndConnect:deviceName services:command.services timeout:60];
}

// 发送命令
- (void)sendCommandForDeviceName:(NSString *)deviceName
{
    FLYCommand * currentCommand = self.deviceCurrentCommands[deviceName];
    
    if ( currentCommand.commandType == FLYCommandTypeWrite )
    {
        [[FLYBluetoothManager sharedManager] writeWithDeviceName:currentCommand.deviceName data:currentCommand.data serviceUUID:currentCommand.serviceUUID characteristicUUID:currentCommand.characteristicUUID];
    }
    else if ( currentCommand.commandType == FLYCommandTypeRead )
    {
        // 读取前先把通知给关闭，不然回调里不能区分是读取的回调还是通知的回调。(回调收到数据后会重新打开)
        [[FLYBluetoothManager sharedManager] setNotifyValue:NO forDeviceName:currentCommand.deviceName serviceUUID:currentCommand.serviceUUID characteristicUUID:currentCommand.characteristicUUID];
        
        [[FLYBluetoothManager sharedManager] readWithDeviceName:currentCommand.deviceName serviceUUID:currentCommand.serviceUUID characteristicUUID:currentCommand.characteristicUUID];
    }
    
    // 执行完之后把操作类型设置成无
    currentCommand.commandType = FLYCommandTypeNone;
}

- (void)handleSuccessWithDataForDeviceName:(NSString *)deviceName data:(nullable NSData *)data
{
    NSMutableArray<FLYCommand *> *queue = self.deviceCommandQueues[deviceName];
    FLYCommand *currentCommand = self.deviceCurrentCommands[deviceName];
    
    // 从该设备的命令队列里移除当前命令
    [queue removeObject:currentCommand];
    
    // 执行回调
    !currentCommand.success ?: currentCommand.success(data);
    
    
    // 继续下一个指令
    [self continueToNextCommandForDeviceName:deviceName];
    
}

- (void)handleFailureForDeviceName:(NSString *)deviceName error:(NSError *)error
{
    NSLog(@"error = %@", error);
    
    NSMutableArray<FLYCommand *> *queue = self.deviceCommandQueues[deviceName];
    FLYCommand *currentCommand = self.deviceCurrentCommands[deviceName];
    
    // 从该设备的命令队列里移除当前命令
    [queue removeObject:currentCommand];

    // 执行回调
    !currentCommand.failure ?: currentCommand.failure(error);
    
    
    // 继续下一个指令
    [self continueToNextCommandForDeviceName:deviceName];
    
}

// 继续执行指定设备的下一个命令
- (void)continueToNextCommandForDeviceName:(NSString *)deviceName
{
    // 清除当前执行命令
    [self.deviceCurrentCommands removeObjectForKey:deviceName];
    
    
    NSMutableArray<FLYCommand *> *queue = self.deviceCommandQueues[deviceName];
    if (queue.count > 0)
    {
        // 取队列第一个命令作为当前命令
        FLYCommand *nextCommand = queue.firstObject;
        self.deviceCurrentCommands[deviceName] = nextCommand;
        
        // 执行命令
        [self executeCommandForDeviceName:deviceName];
    }

}

/// 根据外设的 name 或 subName 获取对应的当前执行命令
/// @param peripheral 蓝牙外设对象
/// @return 返回对应的 FLYCommand 实例，如果找不到则返回 nil
- (FLYCommand *)currentCommandForPeripheral:(CBPeripheral *)peripheral
{
    // 优先根据 peripheral.name 从字典获取命令，若为 nil 则尝试使用 peripheral.subName 作为 key 获取
    return self.deviceCurrentCommands[peripheral.name] ?: self.deviceCurrentCommands[peripheral.subName];
}

/// 根据外设的 name 或 subName 获取对应的命令队列
/// @param peripheral 蓝牙外设对象
/// @return 返回对应设备的命令队列 NSMutableArray<FLYCommand *>，如果找不到则返回 nil
- (NSMutableArray<FLYCommand *> *)commandQueueForPeripheral:(CBPeripheral *)peripheral
{
    // 优先根据 peripheral.name 从字典获取命令队列，若为 nil 则尝试使用 peripheral.subName 作为 key 获取
    return self.deviceCommandQueues[peripheral.name] ?: self.deviceCommandQueues[peripheral.subName];
}

@end


