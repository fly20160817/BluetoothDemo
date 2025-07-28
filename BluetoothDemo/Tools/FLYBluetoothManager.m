//
//  FLYBluetoothManager.m
//  FLYKit
//
//  Created by fly on 2019/12/11.
//  Copyright © 2019 fly. All rights reserved.
//

#import "FLYBluetoothManager.h"
#import "FLYConnectModel.h"
#import "FLYBluetoothManager+Helper.h"


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
 
 
 这里不要用 NSPointerArray ，它是有序数组，不会去重，不会自动清理已释放对象，会留下 NULL 占位。
 
 *************************************************************************/

@interface FLYBluetoothManager ()

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
        
        self.connectModels = [NSMutableArray array];
        
        self.reconnect = YES;
       
        //queue:队列 (传nil就代表在主队列) (不要使用懒加载，早点加载早点拿到蓝牙状态)
        // 因为代理在分类里实现，直接写 self 会警告未遵守代理，强转一下就没有警告了。
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:(id<CBCentralManagerDelegate>)self queue:nil];
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
- (void)scanAndConnect:(NSString *)name services:(nullable NSArray<FLYService *> *)services timeout:(NSInteger)second
{
    // 如果已经连接了，直接调用连接成功的代理，然后return
    FLYConnectModel * connectModel = [self getConnectModelForDeviceName:name];
    if ( connectModel.peripheral.state == CBPeripheralStateConnected )
    {
        [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
            
            if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
            {
                [delegate bluetoothManager:self didConnectPeripheral:connectModel.peripheral];
            }
        }];
        return;
    }
    
    // 如果已经是正在连接中了，不用做其他的，等等就好了
    if ( connectModel.peripheral.state == CBPeripheralStateConnecting )
    {
        return;
    }
    
    
    // 如果 connectModel 存在，说明之前就执行过扫描并连接设备，只是还没有连接上，我们删除它，然后创建新的。
    if ( connectModel != nil )
    {
        // 必须停止计时器，不然从数组移除后，对象也不会销毁，要等计时器结束才会销毁。
        if ( connectModel.isOpenTimer )
        {
            [connectModel stopTimer];
        }
        NSLog(@"此设备已执行过扫描并连接，删除多余的connectModel");
        [self.connectModels removeObject:connectModel];
    }
    
    
    // 如果还没连接，则创建 model 保存数据。
    FLYConnectModel * newModel = [[FLYConnectModel alloc] init];
    newModel.connectName = name;
    newModel.services = services;
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
    
    
    /*
     当外部调用停止扫描时，应清除所有未连接的设备信息。这样做可以防止在下次开启扫描时，可能自动连接到上次未成功连接的设备。
     (内部只有当所有设备都连接后才会调用停止扫描，不存在误删未连接，所以只有外界主动调用停止扫描，才会清空未连接)
     */
    // 使用逆遍历，不然边遍历边删除会闪退
    [self.connectModels enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FLYConnectModel *connectModel, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (connectModel.peripheral == nil)
        {
            // 必须停止计时器，不然从数组移除后，对象也不会销毁，要等计时器结束才会销毁。
            if (connectModel.isOpenTimer)
            {
                [connectModel stopTimer];
            }
            [self.connectModels removeObjectAtIndex:idx];
        }
    }];
}

/// 连接外围设备
- (void)connectPeripheral:(CBPeripheral *)peripheral services:(nullable NSArray<FLYService *> *)services
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
        [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
            
            if ( [delegate respondsToSelector:@selector(bluetoothManager:didConnectPeripheral:)] )
            {
                [delegate bluetoothManager:self didConnectPeripheral:peripheral];
            }
        }];
        
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
        connectModel.services = services;
        [self.connectModels addObject:connectModel];
    }
    
    
    
    //连接外围设备
    [self.centralManager connectPeripheral:peripheral options:nil];
    //设置外围设备的代理 -->一旦连接外设，将由外设来管理服务和特征的处理
    // 因为代理在分类里实现，直接写 self 会警告未遵守代理，强转一下就没有警告了。
    peripheral.delegate = (id<CBPeripheralDelegate>)self;
    
    
    
    // 如果数组里不存在还未开始连接的设备，并且centralManager还在扫描中，就停止扫描（一直扫描浪费资源）
    // (不能因为本设备开始连接了就停止扫描，可能其他设备还没连接还在扫描呢)
    if ( [self isUnconnected] == NO && self.centralManager.isScanning )
    {
        [self stopScan];
    }
    
    
    
    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:connectingPeripheral:)] )
        {
            [delegate bluetoothManager:self connectingPeripheral:peripheral];
        }
    }];
}

/// 断开外围设备
- (void)disconnectPeripheral:(NSString *)deviceName
{
    FLYConnectModel * connectModel = [self getConnectModelForDeviceName:deviceName];
    
    if (connectModel == nil)
    {
        return;
    }
    
    // 如果已经连接了
    if ( connectModel.peripheral != nil )
    {
        [self.centralManager cancelPeripheralConnection:connectModel.peripheral];
    }
    // 如果还没连接上
    else
    {
        /*
         设备还没有连接上，还在扫描中就执行了断开连接指令，
         此时要把它从数组中移除，如果没有其他要扫描的设备，就停止扫描。
         */
        
        // 必须停止计时器，不然从数组移除后，对象也不会销毁，要等计时器结束才会销毁。
        if ( connectModel.isOpenTimer )
        {
            [connectModel stopTimer];
        }
        [self.connectModels removeObject:connectModel];
        
        // 如果数组里不存在还未开始连接的设备，并且centralManager还在扫描中，就停止扫描（一直扫描浪费资源）
        if ( [self isUnconnected] == NO && self.centralManager.isScanning )
        {
            [self stopScan];
        }
    }
    
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
- (void)readWithDeviceName:(NSString *)deviceName serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID
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
    CBCharacteristic * characteristic = [self getCharacteristicWithPeripheral:peripheral serviceUUID:serviceUUID characteristicUUID:characteristicUUID];
    
    if ( characteristic == nil )
    {
        NSLog(@"%@ 读取数据失败，未找到 %@ 特征", deviceName, characteristicUUID);
        
        [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
            
            if ( [delegate respondsToSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)] )
            {
                NSString * domain = [NSString stringWithFormat:@"%@ 读取数据失败，未找到 %@ 特征", deviceName, characteristicUUID];
                NSError * err = [NSError errorWithDomain:domain code:10086 userInfo:nil];
                [delegate peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:err];
            }
        }];
        
        return;
    }
    
    
    // 读取特征的值
    [peripheral readValueForCharacteristic:characteristic];
}

/// 往特征里写入数据
- (void)writeWithDeviceName:(NSString *)deviceName data:(NSData *)data serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID
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
    CBCharacteristic * characteristic = [self getCharacteristicWithPeripheral:peripheral serviceUUID:serviceUUID characteristicUUID:characteristicUUID];

    if ( characteristic == nil )
    {
        NSLog(@"%@ 写入数据失败，未找到 %@ 特征", deviceName, characteristicUUID);
        
        [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
            
            if ( [delegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)] )
            {
                NSString * domain = [NSString stringWithFormat:@"%@ 写入数据失败，未找到 %@ 特征", deviceName, characteristicUUID];
                NSError * err = [NSError errorWithDomain:domain code:10086 userInfo:nil];
                [delegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:err];
            }
        }];
        
        return;
    }
    
    
    /*
     在使用 Core Bluetooth 框架进行蓝牙通信时，写入特征值通常有两种方式：

     1.CBCharacteristicWriteWithResponse: 写入特征值时需要外设返回响应，可以通过 peripheral:didWriteValueForCharacteristic:error: 方法来接收写入操作的结果。这种方式可以确保写入操作的准确性，但因为需要等待外设响应，可能会增加通信的延迟。
     
     2.CBCharacteristicWriteWithoutResponse: 写入特征值时无需外设返回响应，即写入操作后不等待外设的确认。这种方式适用于一些实时数据传输场景，可以减少通信的延迟，但写入操作的准确性可能没有保障。
     */

    

    // 优先使用带响应的写入方式（如果支持）
    if (characteristic.properties & CBCharacteristicPropertyWrite)
    {
        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
    // 否则使用无响应写入方式（如果支持）
    else if (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)
    {
        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        
        
        /* 无需响应的写入，是没有成功和失败的回调的，这里手动调用写入成功的回调，让外界知道已经写完了。 外界的指令队列就可以执行下一条了*/
        
        [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
            
            if ( [delegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)] )
            {
                [delegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:nil];
            }
        }];
    }
        
}

// 开启或关闭特征值的通知
- (void)setNotifyValue:(BOOL)enabled forDeviceName:(NSString *)deviceName serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID
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
    CBCharacteristic * characteristic = [self getCharacteristicWithPeripheral:peripheral serviceUUID:serviceUUID characteristicUUID:characteristicUUID];

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
    
    

    [self enumerateDelegatesUsingBlock:^(id<FLYBluetoothManagerDelegate> delegate) {
        
        if ( [delegate respondsToSelector:@selector(bluetoothManager:didTimeoutForDeviceName:)] )
        {
            [delegate bluetoothManager:self didTimeoutForDeviceName:connectModel.connectName];
        }
    }];
    
}


@end

