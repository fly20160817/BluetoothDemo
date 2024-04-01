//
//  FLYBluetoothManager.m
//  FLYKit
//
//  Created by fly on 2019/12/11.
//  Copyright © 2019 fly. All rights reserved.
//

#import "FLYBluetoothManager.h"
#import "FLYConnectModel.h"


/***************************** NSHashTable *****************************
 
 NSHashTable 是 Foundation 框架提供的一个集合类，它可以存储对象的弱引用，而不会增加对象的引用计数。
 
 NSHashTable 和 数组(NSArray) 的区别：
    存储方式：
        NSArray 是有序的集合，它按照元素的顺序进行存储和访问，每个元素都有一个对应的索引。
        NSHashTable 是无序的集合，它不关心元素的顺序，元素之间没有索引。
    元素唯一性：
        NSArray 中的元素可以重复，而 NSHashTable 中的元素是唯一的，不会重复存储相同的对象。
    引用计数：
        NSArray 中的对象在添加到数组后会自动进行一次引用计数的增加操作。
        NSHashTable 使用弱引用来存储对象，不会对对象进行额外的引用计数操作。
    自动移除：
        NSHashTable 可以通过设置为弱引用来自动移除其中的对象，避免悬挂指针（野指针）问题。
 
 *************************************************************************/

@interface FLYBluetoothManager () < CBCentralManagerDelegate, CBPeripheralDelegate >

// 存放代理对象的数组 (本单例类中实现了一对多的代理，即一个单例类可以有多个代理对象)
@property (nonatomic, strong) NSHashTable<id<FLYBluetoothManagerDelegate>> * delegates;

//中央管理者
@property (nonatomic, strong) CBCentralManager * centralManager;

// 蓝牙状态
@property (nonatomic, assign) CBManagerState state;

//是否正在扫描外设中
//（只要调用了我们的-(void)startScan方法，isScanning就会为YES，即使iPhone蓝牙没开扫描失败也是YES，此时打开蓝牙，蓝牙状态变化的代理中，会判断我们定义的isScanning属性是否正在扫描中，如果是YES就自动开始扫描。不要使用centralManager.isScanning，扫描失败就会是NO，此时打开蓝牙也无法继续扫描）
@property(nonatomic, assign) BOOL isScanning;

// 存放连接模型的数组  (因为支持同时连接多个外设，所以很多的连接数据都放到连接模型里了)
@property (nonatomic, strong) NSMutableArray<FLYConnectModel *> * connectModels;

@end


@implementation FLYBluetoothManager

static FLYBluetoothManager * _manager;

+ (instancetype)sharedManager
{
    if ( _manager == nil )
    {
        _manager = [[self alloc] init];
    }

    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        //创建 NSHashTable 对象，并指定使用弱引用存储对象。
        //weakObjectsHashTable方法创建的 NSHashTable 对象中，存储的对象是弱引用，也就是说，当存储在该表中的对象被释放时，表会自动将其从集合中移除，避免了出现悬挂指针（野指针）的问题。
        self.delegates = [NSHashTable weakObjectsHashTable];
        
        self.reconnect = YES;
        
        //queue:队列 (传nil就代表在主队列) (不要使用懒加载，早点加载早点拿到蓝牙状态)
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

//分配内存地址的时候调用 (当执行alloc的时候，系统会自动调用分配内存地址的方法)
+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    if ( !_manager )
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _manager = [super allocWithZone:zone];
        });
    }
    return _manager;
}

//保证copy这个对象的时候，返回的还是这个单利，不会生成新的
-(id)copyWithZone:(NSZone *)zone
{
    return _manager;
}

//保证copy这个对象的时候，返回的还是这个单利，不会生成新的
-(id)mutableCopyWithZone:(NSZone *)zone
{
    return _manager;
}



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
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManagerDidUpdateState:)] )
        {
            [delegate bluetoothManagerDidUpdateState:central.state];
        }
    }
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
                            peripheral.subName = value;
                            //peripheral必须保存起来才能连接，不然会被释放。
                            connectModel.peripheral = peripheral;
                        
                            [self connectPeripheral:peripheral];
                            break;
                        }
                    }
                }
            }
        }
    }
    
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didDiscoverPeripheral:advertisementData:RSSI:)] )
        {
            [delegate bluetoothManager:self didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        }
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
    
    
    //扫描服务
    [peripheral discoverServices:nil];
    
    //可扫描指定的服务，传nil代表扫描所有服务
//    CBUUID * UUID = [CBUUID UUIDWithString:serviceUUID];
//    [self.peripheral discoverServices:@[UUID]];
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
        {
            [delegate bluetoothManager:self didConnectPeripheral:peripheral];
        }
    }
}

//连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSLog(@"连接外设失败：%@, error：%@", peripheral, error);
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didFailToConnectPeripheral:error:)] )
        {
            [delegate bluetoothManager:self didFailToConnectPeripheral:peripheral error:error];
        }
    }
    
    
    // 从数组中删除
    FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
    [self.connectModels removeObject:connectModel];
}

//断开外设连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    // 从数组里删除 (先从数组里删除，如果先执行了下面的重连代码再执行删除，重连添加进去的又被删除了)
    FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
    [self.connectModels removeObject:connectModel];
    
    
    if ( error )
    {
        NSLog(@"外设连接意外断开：%@", peripheral);
        NSLog(@"意外断开原因：%@", error);
    
        // 是否重连
        if( self.reconnect )
        {
            [self connectPeripheral:peripheral];
        }
    }
    else
    {
        NSLog(@"外设连接断开成功：%@", peripheral);
    }
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didDisconnectPeripheral:error:)] )
        {
            [delegate bluetoothManager:self didDisconnectPeripheral:peripheral error:error];
        }
    }

}



#pragma mark - CBPeripheralDelegate 外设代理

// 扫描到外设的服务时回调 (即使有多个服务，也只会回调一次，拿到的是数组，所有的服务都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if( error )
    {
        NSLog(@"%@ 扫描服务出错：%@", peripheral.subName ? peripheral.subName : peripheral.name, error);
    }
    
    
    for (CBService * service in peripheral.services )
    {
        NSLog(@"%@ 发现服务：%@",  peripheral.subName ? peripheral.subName : peripheral.name, service);
        
        //扫描特征
        [peripheral discoverCharacteristics:nil forService:service];
        
//        // 可扫描指定的特征，传nil代表扫描所有特征
//        CBUUID * UUID = [CBUUID UUIDWithString:characteristicUUID];
//        [self.peripheral discoverCharacteristics:@[UUID] forService:service];
    }
    
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(peripheral:didDiscoverServices:)] )
        {
            [delegate peripheral:peripheral didDiscoverServices:error];
        }
    }
}

// 扫描到服务的特征时回调  (一个服务只会回调一次，拿到的是数组，该服务的所有特征都在里面)
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
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

             
            // 开启特征值的通知 (开启通知后，在 peripheral:didUpdateValueForCharacteristic:error: 代理中监听特征值的更新通知。)
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    
    // 等上面代码都执行完了，在执行代理。防止外界在代理中实现了一些功能，又执行代理下面的代码，导致外界实现的功能被更改。
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)] )
        {
            [delegate peripheral:peripheral didDiscoverCharacteristicsForService:service error:error];
        }
    }
    
}

// 特征值更新通知 或 读取特征值 时回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    /* 通常情况下，通知、读、写操作会使用不同的特征来实现，但也有一些特殊情况下可能会使用同一个特征来实现通知、读、写功能。这主要取决于蓝牙设备的设计和实现。
    
        通过特征的 isNotifying 属性来判断是谁的回调，YES是通知的回调(setNotifyValue:forCharacteristic:)，NO是主动读取的回调(readValueForCharacteristic:)。
        
        如果一个特征开启了通知，再执行读的操作，isNotifying就会不准确，无法判断是读取还是通知的回调。(最好读的特征就别在开通知了，但也有例外，比如某个特征值存储的是电量，开启通知，电量变化会主动通知，但也可以主动去读取一下电量还剩多少。)
     */
    
    NSString * name = peripheral.subName ? peripheral.subName : peripheral.name;
    NSString * tips = characteristic.isNotifying ? @"更新通知" : @"读取结果";// 可能不准，原因见上面注释
    id content = error ? error : characteristic.value;
    
    NSLog(@"%@ 的 %@ 特征值%@：%@", name, characteristic.UUID.UUIDString, tips, content);
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)] )
        {
            [delegate peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:error];
        }
    }

}


//写入数据回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if ( error )
    {
        NSLog(@"%@ 写入失败：%@", peripheral.subName ? peripheral.subName : peripheral.name,  error);
    }
    else
    {
        NSLog(@"%@ 写入成功", peripheral.subName ? peripheral.subName : peripheral.name);
    }
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)] )
        {
            [delegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:error];
        }
    }
    
}



#pragma mark - public methods

/// 添加代理
- (void)addDelegate:(id<FLYBluetoothManagerDelegate>)delegate
{
    [self.delegates addObject:delegate];
}

/// 移除代理
- (void)removeDelegate:(id<FLYBluetoothManagerDelegate>)delegate
{
    [self.delegates removeObject:delegate];
}

/// 扫描并连接设备
/// - Parameters:
///   - name: 需要连接的 设备名字 或 广播里的某个值
///   - second: 超时时间 (设置为0时，则永不超时)(超时后会停止扫描)
- (void)scanAndConnect:(NSString *)name timeout:(NSInteger)second
{
    // 如果已经连接了，直接调用连接成功的代理，然后retun
    FLYConnectModel * connectModel = [self getConnectModelForDeviceName:name];
    if ( connectModel.peripheral.state == CBPeripheralStateConnected )
    {
        // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
        NSHashTable * tempDelegates = self.delegates.copy;
        
        // 遍历所有代理，并执行回调
        for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
        {
            if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
            {
                [delegate bluetoothManager:self didConnectPeripheral:connectModel.peripheral];
            }
        }
        return;
    }
    
    
    // 如果还没连接，则创建 model 保存数据。
    FLYConnectModel * newModel = [[FLYConnectModel alloc] init];
    newModel.connectName = name;
    newModel.second = second;
    newModel.timeoutBlock = ^(FLYConnectModel *model) {
        
        [self timeoutAction:model];
    };
    [self.connectModels addObject:newModel];
    
    
    //开始扫描
    [self startScan];
    
}

/// 开始扫描周边设备
- (void)startScan
{
    //扫描周边设备 (Services:是服务的UUID，而且是一个数组。如果不传，默认扫描所有服务)
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    self.isScanning = YES;
    
    
    // 遍历所有还未连接的设备，根据条件打开它的计时器
    for ( FLYConnectModel *connectModel in self.connectModels )
    {
        // 如果没有peripheral，说明还没开始连接
        if ( connectModel.peripheral == nil )
        {
            // 如果是正在扫描的状态，倒计时的秒数大于0，倒计时未开启，则开始超时倒计时。 (因为蓝牙状态如果不是CBManagerStatePoweredOn，会导致扫描失败，所以此时不能开始计时。当蓝牙状态改变成PoweredOn时，会再次回到这个方法里，此时就是正在扫描的状态，开始计时。)
            if ( self.centralManager.isScanning && connectModel.second > 0 && connectModel.isOpenTimer == NO )
            {
                [connectModel startTimer];
            }
        }
    }
    
}

/// 停止扫描周边设备
- (void)stopScan
{
    [self.centralManager stopScan];
    self.isScanning = NO;
}

/// 连接外围设备
- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    /*
      disconnected 外围设备没有连接到中央经理
     
      connecting 外围设备正在连接到中央经理
     
      connected 外围设备已连接到中央经理
     
      disconnecting 外围设备正在与中央经理断开连接
     */
    
    
    // 如果已经连接了，直接调用连接成功的代理，然后retun
    if ( peripheral.state == CBPeripheralStateConnected )
    {
        // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
        NSHashTable * tempDelegates = self.delegates.copy;
        
        // 遍历所有代理，并执行回调
        for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
        {
            if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
            {
                [delegate bluetoothManager:self didConnectPeripheral:peripheral];
            }
        }
        return;
    }
    
    
    
    FLYConnectModel * connectModel = [self getConnectModelForPeripheral:peripheral];
    
    // 如果有值，说明外界用的是扫描并连接，模型在扫描并连接的方法里就创建了，在连接前停止它的计时器
    if( connectModel )
    {
        // 停止计时器
        if ( connectModel.isOpenTimer )
        {
            [connectModel stopTimer];
        }
    }
    // 如果没值，说明外界直接调连接方法，这里就需要创建模型。
    else
    {
        connectModel = [[FLYConnectModel alloc] init];
        //peripheral必须保存起来才能连接，不然会被释放。
        connectModel.peripheral = peripheral;
        [self.connectModels addObject:connectModel];
    }
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:connectingPeripheral:)] )
        {
            [delegate bluetoothManager:self connectingPeripheral:peripheral];
        }
    }
        
    
    //连接外围设备
    [self.centralManager connectPeripheral:peripheral options:nil];
    //设置外围设备的代理 -->一旦连接外设，将由外设来管理服务和特征的处理
    peripheral.delegate = self;
    
    
    
    // 如果数组里不存在还未开始连接的设备，并且centralManager还在扫描中，就停止扫描（一直扫描浪费资源）
    // (不能因为本设备开始连接了就停止扫描，可能其他设备还没连接还在扫描呢)
    if ( [self isUnconnected] == NO && self.centralManager.isScanning )
    {
        [self stopScan];
    }
}

/// 断开外围设备
- (void)disconnectPeripheral:(NSString *)deviceName
{
    FLYConnectModel * connectModel = [self getConnectModelForDeviceName:deviceName];
    [self.centralManager cancelPeripheralConnection:connectModel.peripheral];
}

/// 设备是否已连接
- (BOOL)isConnected:(NSString *)deviceName
{
    FLYConnectModel * connectModel = [self getConnectModelForDeviceName:deviceName];
    if ( connectModel.peripheral.state == CBPeripheralStateConnected )
    {
        return YES;
    }
    return NO;
}

/// 读取特征的值
- (void)readWithDeviceName:(NSString *)deviceName characteristicUUID:(NSString *)characteristicUUID
{
    // 获取设备
    CBPeripheral * peripheral = [self getConnectModelForDeviceName:deviceName].peripheral;
    
    // 获取不到设备说明没连接
    if ( peripheral == nil )
    {
        NSLog(@"读取数据失败，未找到设备 %@", deviceName);
        return;
    }
    
    
    // 获取特征
    CBCharacteristic * characteristic = [self getCharacteristicsWithPeripheral:peripheral characteristicUUID:characteristicUUID];
    
    // 特征的UUID都是开发时和硬件部门定好的，不存在找不到的情况，所以这里不需要搞失败的回调。
    if ( characteristic == nil )
    {
        NSLog(@"读取数据失败，未找到 %@ 特征", characteristicUUID);
        return;
    }
    
    
    // 读取特征的值
    [peripheral readValueForCharacteristic:characteristic];
}

/// 往特征里写入数据
- (void)writeWithDeviceName:(NSString *)deviceName data:(NSData *)data characteristicUUID:(NSString *)characteristicUUID
{
    // 获取设备
    CBPeripheral * peripheral = [self getConnectModelForDeviceName:deviceName].peripheral;
    
    // 获取不到设备说明没连接
    if ( peripheral == nil )
    {
        NSLog(@"写入数据失败，未找到设备 %@", deviceName);
        return;
    }
    
    
    // 获取特征
    CBCharacteristic * characteristic = [self getCharacteristicsWithPeripheral:peripheral characteristicUUID:characteristicUUID];
    
    // 特征的UUID都是开发时和硬件部门定好的，不存在找不到的情况，所以这里不需要搞失败的回调。
    if ( characteristic == nil )
    {
        NSLog(@"写入数据失败，未找到 %@ 特征", characteristicUUID);
        return;
    }
    
    
    /*
     在使用 Core Bluetooth 框架进行蓝牙通信时，写入特征值通常有两种方式：

     1.CBCharacteristicWriteWithResponse: 写入特征值时需要外设返回响应，可以通过 peripheral:didWriteValueForCharacteristic:error: 方法来接收写入操作的结果。这种方式可以确保写入操作的准确性，但因为需要等待外设响应，可能会增加通信的延迟。
     
     2.CBCharacteristicWriteWithoutResponse: 写入特征值时无需外设返回响应，即写入操作后不等待外设的确认。这种方式适用于一些实时数据传输场景，可以减少通信的延迟，但写入操作的准确性可能没有保障。
     */

    
    // 这两个属性它们是互斥的。一个特征只能具有其中的一种属性，不可能同时具有这两个属性。
    
    // 默认是 需要外设返回响应 类型
    CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
    
    // 如果特征具有无需响应的写入属性，则改为 无需外设返回响应 类型
    if (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)
    {
        writeType = CBCharacteristicWriteWithoutResponse;
    }
    
    [peripheral writeValue:data forCharacteristic:characteristic type:writeType];
    
}

// 开启或关闭特征值的通知
- (void)setNotifyValue:(BOOL)enabled forDeviceName:(NSString *)deviceName characteristicUUID:(NSString *)characteristicUUID
{
    // 获取设备
    CBPeripheral * peripheral = [self getConnectModelForDeviceName:deviceName].peripheral;
    
    // 获取不到设备说明没连接
    if ( peripheral == nil )
    {
        NSLog(@"通知设置失败，未找到设备 %@", deviceName);
        return;
    }
    
    
    // 获取特征
    CBCharacteristic * characteristic = [self getCharacteristicsWithPeripheral:peripheral characteristicUUID:characteristicUUID];
    
    // 特征的UUID都是开发时和硬件部门定好的，不存在找不到的情况，所以这里不需要搞失败的回调。
    if ( characteristic == nil )
    {
        NSLog(@"通知设置据失败，未找到 %@ 特征", characteristicUUID);
        return;
    }
    
    
    // 特征具有通知属性 （&是位运算中的按位与操作符）
    if (characteristic.properties & CBCharacteristicPropertyNotify)
    {
        // 开启或关闭特征值的通知
        [peripheral setNotifyValue:enabled forCharacteristic:characteristic];
    }

}



#pragma mark - action

// 超时执行的事件
- (void)timeoutAction:(FLYConnectModel *)connectModel
{
    NSLog(@"扫描外设超时，未找到：%@", connectModel.connectName);
    
    // 移除此模型 (如果不移除，后面如果又扫出来了，又会自动连接，但我们已经报超时了，后面就不要再连接了)
    [self.connectModels removeObject:connectModel];
    
    
    // 如果数组里不存在还未开始连接的设备，并且centralManager还在扫描中，就停止扫描（一直扫描浪费资源）
    // (不能因为本设备超时了就停止扫描，可能其他设备还没连接还在扫描呢)
    if ( [self isUnconnected] == NO && self.centralManager.isScanning )
    {
        [self stopScan];
    }
    
    
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    //超时回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didTimeoutForDeviceName:)] )
        {
            [delegate bluetoothManager:self didTimeoutForDeviceName:connectModel.connectName];
        }
    }
    
}



#pragma mark - private methods

// 根据 peripheral ，从数组中找到指定的 model
- (FLYConnectModel *)getConnectModelForPeripheral:(CBPeripheral *)peripheral
{
    // 遍历数组，找到指定的model
    for ( FLYConnectModel *connectModel in self.connectModels )
    {
        if ( connectModel.peripheral == peripheral )
        {
            return connectModel;
        }
    }
    
    return nil;
}

// 根据 deviceName ，从数组中找到指定的 model
- (FLYConnectModel *)getConnectModelForDeviceName:(NSString *)deviceName
{
    // 遍历数组，找到指定的model
    for ( FLYConnectModel *connectModel in self.connectModels )
    {
        if ( [connectModel.peripheral.name isEqualToString:deviceName] || [connectModel.peripheral.subName isEqualToString:deviceName]  )
        {
            return connectModel;
        }
    }
    
    return nil;
}

// 获取指定的特征
- (CBCharacteristic *)getCharacteristicsWithPeripheral:(CBPeripheral *)peripheral characteristicUUID:(NSString *)characteristicUUID
{
    // 遍历外设中的服务 -> 遍历服务中的特征 -> 找到指定特征
    for (CBService * service in peripheral.services)
    {
        for (CBCharacteristic * characteristic in service.characteristics)
        {
            if ( [characteristic.UUID.UUIDString isEqualToString:characteristicUUID] )
            {
                return characteristic;
            }
        }
    }
    
    return nil;
}

/// 数组里是否存在还未开始连接的设备
- (BOOL)isUnconnected
{
    // 遍历所有的模型，如果没有peripheral，说明还没开始连接 (只要开始连接了，就能停止扫描了，不用等连上)
    for (FLYConnectModel * connectModel in self.connectModels)
    {
        if( connectModel.peripheral == nil )
        {
            return YES;
        }
    }
    
    return NO;
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




