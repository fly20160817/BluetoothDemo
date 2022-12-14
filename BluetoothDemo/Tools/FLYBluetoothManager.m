//
//  FLYBluetoothManager.m
//  FLYKit
//
//  Created by fly on 2019/12/11.
//  Copyright © 2019 fly. All rights reserved.
//

#import "FLYBluetoothManager.h"
#import "FLYConnectModel.h"

@interface FLYBluetoothManager () < CBCentralManagerDelegate, CBPeripheralDelegate >

//中央管理者
@property (nonatomic, strong) CBCentralManager * centralManager;

//蓝牙状态
@property (nonatomic, assign, readwrite) CBManagerState state;

// 存放连接模型的数组  (因为支持同时连接多个外设，所以很多的连接数据都放到连接模型里了)
@property (nonatomic, strong) NSMutableArray<FLYConnectModel *> * connectModels;

@end


@implementation FLYBluetoothManager

+ (instancetype) sharedManager
{
    static FLYBluetoothManager * _manager;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _manager = [[FLYBluetoothManager alloc] init];
    });
    
    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        //queue:队列。如果传空就代表在主队列
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}



#pragma mark - CBCentralManagerDelegate 中央管理者代理

//判断设备的更新状态 (必须执行的代理)
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBManagerStateUnknown:
            NSLog(@"中心管理器状态未知");
            break;
            
        case CBManagerStateResetting:
            NSLog(@"中心管理器状态重置");
            break;
            
        case CBManagerStateUnsupported:
            NSLog(@"中心管理器状态不被支持");
            break;
            
        case CBManagerStateUnauthorized:
            NSLog(@"中心管理器状态未被授权");
            break;
            
        case CBManagerStatePoweredOff:
            NSLog(@"中心管理器状态电源关闭");
            break;
            
        case CBManagerStatePoweredOn:
        {
            NSLog(@"中心管理器状态电源开启");
            //扫描周边设备
            [central scanForPeripheralsWithServices:nil options:nil];
        }
            break;
            
        default:
            break;
    }


    self.state = central.state;
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
    //NSLog(@"扫描到外设：%@", peripheral);
    
    for ( FLYConnectModel * connectModel in self.connectModels)
    {
        // 是否有扫描并连接的name
        if ( connectModel.connectName )
        {
            //如果需要连接的name等于外围设备name，则停止扫描并连接
            if ( [peripheral.name isEqualToString:connectModel.connectName] )
            {
                connectModel.peripheral = peripheral;
                
                [self stopScan];
                [self connectPeripheral:peripheral];
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
                            connectModel.subName = value;
                            connectModel.peripheral = peripheral;
                            
                            [self stopScan];
                            [self connectPeripheral:peripheral];
                            break;
                        }
                    }
                }
            }
        }
    }
   
    
    
    if ( [self.delegate respondsToSelector:@selector(bluetoothManager:didDiscoverPeripheral:advertisementData:RSSI:)] )
    {
        [self.delegate bluetoothManager:self didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
    }
}

/**
 连接到外设后调用

 @param central 中央管理者
 @param peripheral 外围设备
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接外设成功：%@", peripheral);
    
    for ( FLYConnectModel * connectModel in self.connectModels )
    {
        if ( connectModel.peripheral == peripheral )
        {
            // 连接成功之后，不要马上执行连接成功的回调，等个0.5秒，给扫描服务和扫描特征留点时间，扫描完毕之后再执行回调，保证外界在这个block里可以直接执行其他的蓝牙操作(扫描服务和扫描特征没完成的话，不能执行其他的蓝牙操作)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                // 执行连接成功的回调
                !connectModel.connectSuccessBlock ?: connectModel.connectSuccessBlock(peripheral);
            });
        }
    }
    
    
    if ( [self.delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
    {
        [self.delegate bluetoothManager:self didConnectPeripheral:peripheral];
    }
    
    //扫描服务
    [peripheral discoverServices:nil];
    
    //可扫描指定的服务，传nil代表扫描所有服务
//    CBUUID * UUID = [CBUUID UUIDWithString:serviceUUID];
//    [self.peripheral discoverServices:@[UUID]];
    
}

//连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSLog(@"连接外设失败：%@, error：%@", peripheral, error);
    
    [self.connectModels enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FLYConnectModel * _Nonnull connectModel, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( connectModel.peripheral == peripheral )
        {
            // 执行连接失败的回调
            !connectModel.connectFailureBlock ?: connectModel.connectFailureBlock(error);
            
            // 移除
            [self.connectModels removeObject:connectModel];
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
    }
    else
    {
        NSLog(@"外设连接断开成功：%@", peripheral);
    }
    
    
    [self.connectModels enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FLYConnectModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( obj.peripheral == peripheral )
        {
            [self.connectModels removeObject:obj];
        }
    }];
    
    if ( [self.delegate respondsToSelector:@selector(bluetoothManager:didDisconnectPeripheral:error:)] )
    {
        [self.delegate bluetoothManager:self didDisconnectPeripheral:peripheral error:error];
    }
}



#pragma mark - CBPeripheralDelegate 外设代理

// 扫描到外设的服务时回调 (即使有多个服务，也只会回调一次，拿到的是数组，所有的服务都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService * service in peripheral.services )
    {
        NSLog(@"发现服务：%@", service);
        
        //扫描特征
        [peripheral discoverCharacteristics:nil forService:service];
        
//        // 可扫描指定的特征，传nil代表扫描所有特征
//        CBUUID * UUID = [CBUUID UUIDWithString:characteristicUUID];
//        [self.peripheral discoverCharacteristics:@[UUID] forService:service];
    }
    
    
//    if ( [self.delegate respondsToSelector:@selector(peripheral:didDiscoverServices:)] )
//    {
//        [self.delegate peripheral:peripheral didDiscoverServices:error];
//    }
}

// 扫描到服务的特征时回调  (一个服务只会回调一次，拿到的是数组，该服务的所有特征都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic * characteristic in service.characteristics )
    {
        NSLog(@"发现 %@ 服务的特征：%@", service.UUID.UUIDString, characteristic);
        
        // 订阅, 实时接收 (在didUpdateValueForCharacteristic里返回)
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
    
//    if ( [self.delegate respondsToSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)] )
//    {
//        [self.delegate peripheral:peripheral didDiscoverCharacteristicsForService:service error:error];
//    }
}

//执行readValueForCharacteristic:(读取特征数据)时会调用此代理
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( error )
    {
        NSLog(@"读取失败：%@", error);
    }
    else
    {
        NSLog(@"读取成功：%@", characteristic.value);
    }
    
    
    if ( [self.delegate respondsToSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)] )
    {
        [self.delegate peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:error];
    }
}


//写入数据回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if ( error )
    {
        NSLog(@"写入失败：%@", error);
    }
    else
    {
        NSLog(@"写入成功");
    }
    
    
    if ( [self.delegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)] )
    {
        [self.delegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:error];
    }
}



#pragma mark - public methods

/// 扫描并连接设备 (连接成功后自动停止扫描)
/// - Parameters:
///   - name: 需要连接的 设备名字 或 Mac地址 (如果是用Mac，需要蓝牙设备把Mac地址放到广播中)
///   - successBlock: 连接成功的回调
///   - failureBlock: 连接失败的回调  (搜索不到不会执行连接失败的回调)
- (void)scanAndConnect:(NSString *)name success:(nullable void(^)(CBPeripheral *))successBlock failure:(nullable void(^)(NSError *))failureBlock
{
    // 是否已经连接
    for ( FLYConnectModel *connectModel in self.connectModels )
    {
        // 如果已经连接了，直接返回成功回调，然后retun
        if ( [connectModel.peripheral.name isEqualToString:name] || [connectModel.subName isEqualToString:name]  )
        {
            if ( connectModel.peripheral.state == CBPeripheralStateConnected )
            {
                successBlock(connectModel.peripheral);
                return;
            }
        }
    }
    
    

    FLYConnectModel * connectModel = [[FLYConnectModel alloc] init];
    connectModel.connectName = name;
    connectModel.connectSuccessBlock = successBlock;
    connectModel.connectFailureBlock = failureBlock;
    [self.connectModels addObject:connectModel];
    
    //扫描周边设备
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

/// 开始扫描周边设备
- (void)startScan
{    
    //扫描周边设备 (Services:是服务的UUID，而且是一个数组。如果不传，默认扫描所有服务)
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

/// 停止扫描周边设备
- (void)stopScan
{
    [self.centralManager stopScan];
}

/// 连接外围设备 (连接成功后自动停止扫描)
/// - Parameters:
///   - peripheral: 外设对象
///   - successBlock: 连接成功的回调
///   - failureBlock: 连接失败的回调
- (void)connectPeripheral:(CBPeripheral *)peripheral success:(nullable void(^)(CBPeripheral * peripheral))successBlock failure:(nullable void(^)(NSError * error))failureBlock
{
    
    /*
      disconnected 外围设备没有连接到中央经理
     
      connecting 外围设备正在连接到中央经理
     
      connected 外围设备已连接到中央经理
     
      disconnecting 外围设备正在与中央经理断开连接
     */
    
    
    // 如果已经连接了，直接返回成功回调，然后retun
    if ( peripheral.state == CBPeripheralStateConnected )
    {
        successBlock(peripheral);
        return;
    }
    
    
    
    FLYConnectModel * connectModel = [[FLYConnectModel alloc] init];
    // peripheral必须保存起来才能连接，不然会被释放。
    connectModel.peripheral = peripheral;
    connectModel.connectSuccessBlock = successBlock;
    connectModel.connectFailureBlock = failureBlock;
    [self.connectModels addObject:connectModel];
    
    
    [self connectPeripheral:peripheral];
    
}

/// 连接外围设备
- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    //连接外围设备
    [self.centralManager connectPeripheral:peripheral options:nil];
    
    //设置外围设备的代理 -->一旦连接外设，将由外设来管理服务和特征的处理
    peripheral.delegate = self;
}

/// 断开外围设备
/// - Parameter peripheral: 设备对象  (FLYBluetoothManager支持同时连接多个蓝牙设备，可以指定断开某个设备。如果传nil，则断开的是最后一个连接的蓝牙设备)
- (void)cancelPeripheralConnection:(nullable CBPeripheral *)peripheral
{
    //FLYBluetoothManager支持同时连接多个蓝牙设备，可以指定断开某个设备。如果传nil，则断开的是最后一个连接的蓝牙设备
    if ( peripheral == nil )
    {
        peripheral = self.connectModels.lastObject.peripheral;
    }
    
    [self.centralManager cancelPeripheralConnection:peripheral];
}


/// 读取数据
/// - Parameters:
///   - peripheral: 外设
///   - characteristicUUID: 特征的UUID
- (void)readDataWithPeripheral:(nullable CBPeripheral *)peripheral characteristicUUID:(NSString *)characteristicUUID
{
    if ( peripheral == nil )
    {
        peripheral = self.connectModels.lastObject.peripheral;
    }
    
    // 是否找到特征
    BOOL isFindCharacteristic = NO;
    
    // 遍历外设中的服务 -> 遍历服务中的特征 -> 找到指定特征 -> 读取数据
    for (CBService * service in peripheral.services)
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            if ( [characteristic.UUID.UUIDString isEqualToString:characteristicUUID] )
            {
                isFindCharacteristic = YES;
                [peripheral readValueForCharacteristic:characteristic];
            }
        }
    }
    
    if ( isFindCharacteristic == NO )
    {
        NSLog(@"读取数据失败，未找到 %@ 特征", characteristicUUID);
    }
    
}

/// 写入数据
/// - Parameters:
///   - data: 数据
///   - peripheral: 外设
///   - characteristicUUID: 特征的UUID
- (void)writeData:(NSData *)data peripheral:(nullable CBPeripheral *)peripheral characteristicUUID:(NSString *)characteristicUUID
{
    if ( peripheral == nil )
    {
        peripheral = self.connectModels.lastObject.peripheral;
    }
    
    // 是否找到特征
    BOOL isFindCharacteristic = NO;
    
    // 遍历外设中的服务 -> 遍历服务中的特征 -> 找到指定特征 -> 写入数据
    for (CBService * service in peripheral.services)
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            if ( [characteristic.UUID.UUIDString isEqualToString:characteristicUUID] )
            {
                isFindCharacteristic = YES;
                [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            }
        }
    }
    
    if ( isFindCharacteristic == NO )
    {
        NSLog(@"写入数据失败，未找到 %@ 特征", characteristicUUID);
    }
}



#pragma mark - 数据类型转换

/// 16进制字符串 转 NSData
/// - Parameter hexString: 16进制字符串
+ (NSData *)convertHexStringToData:(NSString *)hexString
{
    if (!hexString || [hexString length] == 0)
    {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:20];
    NSRange range;
    if ([hexString length] % 2 == 0)
    {
        range = NSMakeRange(0, 2);
    }
    else
    {
        range = NSMakeRange(0, 1);
    }
    
    for (NSInteger i = range.location; i < [hexString length]; i += 2)
    {
        unsigned int anInt;
        NSString *hexCharStr = [hexString substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    return hexData;
}

/// Data 转 16进制字符串
/// - Parameter data: data数据
+ (NSString *)convertDataToHexString:(NSData *)data
{
    Byte *bytes = (Byte *)[data bytes];
    NSString *hexStr=@"";
    
    for( int i=0; i < [data length]; i++ )
    {
        //转换成16进制数
        NSString *newHexStr = [NSString stringWithFormat:@"%x", bytes[i]&0xff];
        //如果是一位，则前面补0
        if( [newHexStr length] == 1)
        {
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        }
        else
        {
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
        }
    }
    hexStr = [hexStr uppercaseString];
    return hexStr;
}



#pragma mark - setters and getters

-(NSMutableArray<FLYConnectModel *> *)connectModels
{
    if ( _connectModels == nil )
    {
        _connectModels = [NSMutableArray array];
    }
    return _connectModels;
}


@end


