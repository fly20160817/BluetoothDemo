//
//  FLYBluetoothManager+Delegate.m
//  BluetoothDemo
//
//  Created by fly on 2025/7/25.
//

#import "FLYBluetoothManager+Delegate.h"
#import "FLYConnectModel.h"
#import "FLYBluetoothManager+Helper.h"
#import "BluetoothDemo-Bridging-Header.h"

@interface FLYBluetoothManager ()

/************************************************
 
 这里的属性都是 FLYBluetoothManager 类 .m 文件的私有属性，这里声明一下只是为了能访问到。
 如果 .m 文件的属性名修改了，这里也要改，不然就对应不上了。
 
 ************************************************/



// 存放代理对象的数组
@property (nonatomic, strong) NSHashTable<id<FLYBluetoothManagerDelegate>> * delegates;

//中央管理者
@property (nonatomic, strong) CBCentralManager * centralManager;

// 蓝牙状态
@property (nonatomic, assign) CBManagerState state;

//是否正在扫描外设中
@property(nonatomic, assign) BOOL isScanning;

// 存放连接模型的数组
@property (nonatomic, strong) NSMutableArray<FLYConnectModel *> * connectModels;

@end

@implementation FLYBluetoothManager (Delegate)



#pragma mark - CBCentralManagerDelegate 中央管理者代理

//判断设备的更新状态 (必须执行的代理)
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBManagerStateUnknown:
            NSLog(@"蓝牙状态未知");
            break;
            
        case CBManagerStateResetting:
            NSLog(@"蓝牙正在重置");
            break;
            
        case CBManagerStateUnsupported:
            NSLog(@"蓝牙硬件损坏");
            break;
            
        case CBManagerStateUnauthorized:
            NSLog(@"蓝牙权限被禁");
            break;
            
        case CBManagerStatePoweredOff:
            NSLog(@"蓝牙已关闭");
            break;
            
        case CBManagerStatePoweredOn:
        {
            NSLog(@"蓝牙已开启");
            
            //如果扫描的状态是YES，则开启扫描（防止调用扫描时，iPhone蓝牙没开导致扫描失败，此时打开蓝牙，蓝牙状态变化，这里我们判断是否正在扫描中，如果是就自动开始扫描）
            if( self.isScanning )
            {
                [self startScan];
            }
        }
            break;
            
        default:
            break;
    }
    
    self.state = central.state;

    
    /// 遍历所有代理对象，并执行传入的回调 block。
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManagerDidUpdateState:)] )
        {
            [delegate bluetoothManagerDidUpdateState:central.state];
        }
    }];
}

/**
 当发现外围设备时，会调用的方法

 @param central 中央管理者
 @param peripheral 外围设备
 @param advertisementData 相关的数据
 @param RSSI 信号强度
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    /* 已经连接的设备是扫描不到的 */
    
    NSLog(@"扫描到外设：%@", peripheral);
     
    
    for ( FLYConnectModel * connectModel in self.connectModels)
    {
        // 是否有扫描并连接的name
        if ( connectModel.connectName )
        {
            //如果需要连接的name等于外围设备name，则停止扫描并连接
            if ( [peripheral.name isEqualToString:connectModel.connectName] )
            {
                //peripheral必须保存起来才能连接，不然会被释放。
                connectModel.peripheral = peripheral;
                
                [self connectPeripheral:peripheral services:connectModel.services];
            }
            // 有的时候同名设备太多，不能根据名字来，广播地址里又没有mac，只能用identifier来区分设备
            else if ( [peripheral.identifier.UUIDString isEqualToString:connectModel.connectName] )
            {
                // 保存广播里的这个值
                peripheral.subName = peripheral.identifier.UUIDString;
                //peripheral必须保存起来才能连接，不然会被释放。
                connectModel.peripheral = peripheral;
            
                [self connectPeripheral:peripheral services:connectModel.services];
            }
            else
            {
                //遍历广播字典里的所有value，如果能和传进来的name匹配，则停止扫描并连接 (因为传进来的可能是mac，在广播里找找)
                for (id value in advertisementData.allValues)
                {
                    if ( [value isKindOfClass:[NSString class]] )
                    {
                        if ( [value isEqualToString:connectModel.connectName] )
                        {
                            // 保存广播里的这个值
                            peripheral.subName = value;
                            //peripheral必须保存起来才能连接，不然会被释放。
                            connectModel.peripheral = peripheral;
                        
                            [self connectPeripheral:peripheral services:connectModel.services];
                            break;
                        }
                    }
                    else if ( [value isKindOfClass:[NSData class]] )
                    {
                        NSData *data = (NSData *)value;
                        
                        NSMutableString *hexString = [NSMutableString string];
                        const unsigned char *dataBytes = data.bytes;
                        
                        for (NSInteger i = 0; i < data.length; i++)
                        {
                            // x 是小写
                            [hexString appendFormat:@"%02x", dataBytes[i]];
                        }
                        
                        // 转换 connectName 为小写进行比较（防止大小写不一致）
                        NSString *targetName = [connectModel.connectName lowercaseString];
                        
                        // 如果 kCBAdvDataManufacturerData 包含 connectName，则去连接 (kCBAdvDataManufacturerData里面可能除了mac，还有其他的一些数据，所以用包好，不用等于)
                        if ([hexString containsString:targetName])
                        {
                            peripheral.subName = connectModel.connectName;
                            connectModel.peripheral = peripheral;
                            
                            [self connectPeripheral:peripheral services:connectModel.services];
                            break;
                        }
                    }
                }
                
            }
        }
    }
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didDiscoverPeripheral:advertisementData:RSSI:)] )
        {
            [delegate bluetoothManager:self didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        }
    }];
}

/**
 连接到外设后调用

 @param central 中央管理者
 @param peripheral 外围设备
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接外设成功：%@", peripheral);

    
    FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
    
    //扫描服务（传nil代表扫描所有服务）
    NSArray * UUIDArray = [self extractServiceUUIDsFromServices:connectModel.services];
    [peripheral discoverServices:UUIDArray];
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
        {
            [delegate bluetoothManager:self didConnectPeripheral:peripheral];
        }
    }];
}

//连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSLog(@"连接外设失败：%@, error：%@", peripheral, error);
    
    
    // 从数组中删除
    FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
    [self.connectModels removeObject:connectModel];
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
        {
            [delegate bluetoothManager:self didConnectPeripheral:peripheral];
        }
    }];
}

//断开外设连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    
    if ( error )
    {
        NSLog(@"外设连接意外断开：%@", peripheral);
        NSLog(@"意外断开原因：%@", error);
    
        // 是否重连
        if( self.reconnect )
        {
            FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
            [self connectPeripheral:peripheral services:connectModel.services];
        }
        else
        {
            // 从数组里删除 (上面重连的情况不要删)
            FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
            [self.connectModels removeObject:connectModel];
        }
    }
    else
    {
        NSLog(@"外设连接断开成功：%@", peripheral);
        
        // 从数组里删除
        FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
        [self.connectModels removeObject:connectModel];
    }
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didDisconnectPeripheral:error:)] )
        {
            [delegate bluetoothManager:self didDisconnectPeripheral:peripheral error:error];
        }
    }];

}



#pragma mark - CBPeripheralDelegate 外设代理

// 扫描到外设的服务时回调 (即使有多个服务，也只会回调一次，拿到的是数组，所有的服务都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error
{
    /*
     Core Bluetooth 会缓存设备已发现的服务列表，如果服务列表内容有变动（例如设备固件更新导致服务发生改变），
     需要去设置里关闭并重新打开蓝牙才能搜索到新的服务。
     */
    
    
    
    if( error )
    {
        NSLog(@"%@ 扫描服务出错：%@", peripheral.subName ? peripheral.subName : peripheral.name, error);
    }
    
    
    for (CBService * service in peripheral.services )
    {
        NSLog(@"%@ 发现服务：%@",  peripheral.subName ? peripheral.subName : peripheral.name, service);
        
        // 扫描特征 (传nil代表扫描所有特征)
        FLYService * flyService = [self findFLYServiceFromPeripheral:peripheral cbService:service];
        NSArray * UUIDArray = [self extractCharacteristicUUIDsFromService:flyService];
        [peripheral discoverCharacteristics:UUIDArray forService:service];
    }
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(peripheral:didDiscoverServices:)] )
        {
            [delegate peripheral:peripheral didDiscoverServices:error];
        }
    }];

}

// 扫描到服务的特征时回调  (一个服务只会回调一次，拿到的是数组，该服务的所有特征都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error
{
    if( error )
    {
        NSLog(@"%@ 扫描特征出错：%@", peripheral.subName ? peripheral.subName : peripheral.name, error);
    }
    
    
    for (CBCharacteristic * characteristic in service.characteristics )
    {
        NSLog(@"%@ 的 %@ 服务发现特征：%@", peripheral.subName ? peripheral.subName : peripheral.name, service.UUID.UUIDString, characteristic);
        
        /*
         特征（CBCharacteristic）可以具有以下属性：

         CBCharacteristicPropertiesBroadcast: 表示该特征可以被广播，即可以在广播包中发送特征值。
         CBCharacteristicPropertiesRead: 表示该特征可以读取特征值。
         CBCharacteristicPropertiesWriteWithoutResponse: 表示该特征可以通过写入操作来修改特征值，且无需响应。
         CBCharacteristicPropertiesWrite: 表示该特征可以通过写入操作来修改特征值，并需要响应。
         CBCharacteristicPropertiesNotify: 表示该特征可以发送通知，即可以通过通知来传递特征值的变化。
         CBCharacteristicPropertiesIndicate: 表示该特征可以发送指示，即可以通过指示来传递特征值的变化。
         CBCharacteristicPropertiesAuthenticatedSignedWrites: 表示该特征可以通过身份验证的签名方式进行写操作。
         CBCharacteristicPropertiesExtendedProperties: 表示该特征具有扩展属性。
         CBCharacteristicPropertiesNotifyEncryptionRequired: 表示通知特征值需要加密传输。
         CBCharacteristicPropertiesIndicateEncryptionRequired: 表示指示特征值需要加密传输。
         
         这些属性不是所有蓝牙设备都支持的，具体支持的属性取决于蓝牙设备的设计和实现。在使用特征时，可以通过检查特征的属性来判断设备是否支持某些功能。
         */


        // CBCharacteristicProperties 是一个位域枚举（bitwise enum），这意味着每个枚举值都是一个独立的位。在内存中，这些枚举值可以组合在一起，形成一个表示多个属性的位掩码。

         
        // 特征具有写入属性
        if (characteristic.properties & CBCharacteristicPropertyWrite)
        {
            NSLog(@"%@ 特征具有写入属性", characteristic.UUID);
        }

        // 特征具有无需响应的写入属性
        if (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)
        {
            NSLog(@"%@ 特征具有无需响应写入属性", characteristic.UUID);
        }
        
        // 特征具有读取属性
        if (characteristic.properties & CBCharacteristicPropertyRead)
        {
            NSLog(@"%@ 特征具有读取属性", characteristic.UUID);
        }
        
        // 特征具有通知属性 （&是位运算中的按位与操作符）
        if (characteristic.properties & CBCharacteristicPropertyNotify)
        {
             NSLog(@"%@ 特征具有通知属性", characteristic.UUID);

            FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
            
            // 如果没有设置扫描的服务和特征，那就是扫描所有的，通知也是所有的
            if ( connectModel.services.count == 0 )
            {
                // 开启特征值的通知 (开启通知后，在 peripheral:didUpdateValueForCharacteristic:error: 代理中监听特征值的更新通知。)
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            // 如果设置了指定扫描的服务和特征，则需要判断该服务特征是否在指定的里面。
            else
            {
                FLYService * flyService = [self findFLYServiceFromPeripheral:peripheral cbService:service];
                NSArray * UUIDArray = [self extractCharacteristicUUIDsFromService:flyService];
                
                if ( [UUIDArray containsObject:characteristic.UUID] )
                {
                    // 开启特征值的通知 (开启通知后，在 peripheral:didUpdateValueForCharacteristic:error: 代理中监听特征值的更新通知。)
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }
            }
        }
    }
    
    
    // 等上面代码都执行完了，在执行代理。防止外界在代理中实现了一些功能，又执行代理下面的代码，导致外界实现的功能被更改。
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)] )
        {
            [delegate peripheral:peripheral didDiscoverCharacteristicsForService:service error:error];
        }
    }];
    
}

// 特征值更新通知 或 读取特征值 时回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    /* 通常情况下，通知、读、写操作会使用不同的特征来实现，但也有一些特殊情况下可能会使用同一个特征来实现通知、读、写功能。这主要取决于蓝牙设备的设计和实现。
    
        通过特征的 isNotifying 属性来判断是谁的回调，YES是通知的回调(setNotifyValue:forCharacteristic:)，NO是主动读取的回调(readValueForCharacteristic:)。
        
        如果一个特征开启了通知，再执行读的操作，isNotifying就会不准确，无法判断是读取还是通知的回调。(最好读的特征就别在开通知了，但也有例外，比如某个特征值存储的是电量，开启通知，电量变化会主动通知，但也可以主动去读取一下电量还剩多少。)
     */
    
    NSString * name = peripheral.subName ? peripheral.subName : peripheral.name;
    NSString * tips = characteristic.isNotifying ? @"更新通知" : @"读取结果";// 可能不准，原因见上面注释
    id content = error ? error : characteristic.value;
    
    NSLog(@"%@ 的 %@ 特征值%@：%@", name, characteristic.UUID.UUIDString, tips, content);
    
    

    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)] )
        {
            [delegate peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:error];
        }
    }];

}

//写入数据回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if ( error )
    {
        NSLog(@"%@ 写入失败：%@", peripheral.subName ? peripheral.subName : peripheral.name,  error);
    }
    else
    {
        NSLog(@"%@ 写入成功", peripheral.subName ? peripheral.subName : peripheral.name);
    }
    
    

    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)] )
        {
            [delegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:error];
        }
    }];
    
}

// 当通知状态（即是否监听特征值的变化）发生变化时会被调用。这个方法可以用来处理成功或失败的通知订阅操作。
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if( error )
    {
        NSLog(@"%@ 订阅或取消订阅 %@ 特征通知出错：%@", peripheral.subName ? peripheral.subName : peripheral.name, characteristic.UUID.UUIDString, error);
    }
    else
    {
        if (characteristic.isNotifying) {
            
            NSLog(@"%@ 订阅 %@ 特征通知成功", peripheral.subName ? peripheral.subName : peripheral.name, characteristic.UUID.UUIDString);
        }
        else
        {
            NSLog(@"%@ 取消订阅 %@ 特征通知成功", peripheral.subName ? peripheral.subName : peripheral.name, characteristic.UUID.UUIDString);
        }
    }
    
    

    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(peripheral:didUpdateNotificationStateForCharacteristic:error:)] )
        {
            [delegate peripheral:peripheral didUpdateNotificationStateForCharacteristic:characteristic error:error];
        }
    }];
}


@end
