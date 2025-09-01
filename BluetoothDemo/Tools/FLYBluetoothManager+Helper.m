//
//  FLYBluetoothManager+Helper.m
//  BluetoothDemo
//
//  Created by fly on 2025/7/28.
//

#import "FLYBluetoothManager+Helper.h"

@interface FLYBluetoothManager ()

/************************************************
 
 这里的属性都是 FLYBluetoothManager 类 .m 文件的私有属性，这里声明一下只是为了能访问到。
 如果 .m 文件的属性名修改了，这里也要改，不然就对应不上了。
 
 ************************************************/



// 存放代理对象的数组
@property (nonatomic, strong) NSHashTable<id<FLYBluetoothManagerDelegate>> * delegates;

// 存放连接模型的数组
@property (nonatomic, strong) NSMutableArray<FLYConnectModel *> * connectModels;

@end

@implementation FLYBluetoothManager (Helper)



/// 遍历所有代理对象，并执行传入的回调 block。
- (void)enumerateDelegatesUsingBlock:(void (^)(id<FLYBluetoothManagerDelegate> delegate))block
{
    // 外界可能在代理中移除代理，此时一边遍历一边删除会崩溃，搞个临时数组来遍历，外界删除就不会崩溃了。
    NSHashTable * tempDelegates = self.delegates.copy;
    
    // 遍历所有代理，并执行回调
    for ( id<FLYBluetoothManagerDelegate> delegate in tempDelegates )
    {
        if (block)
        {
            block(delegate);
        }
    }
}


/// 根据 peripheral ，从数组中找到指定的 model
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


/// 根据 deviceName ，从数组中找到指定的 model
- (FLYConnectModel *)getConnectModelForDeviceName:(NSString *)deviceName
{
    // 遍历数组，找到指定的model
    for ( FLYConnectModel *connectModel in self.connectModels )
    {
        if ( [connectModel.connectName isEqualToString:deviceName] )
        {
            return connectModel;
        }
    }
    
    return nil;
}


/// 获取指定的特征
- (CBCharacteristic *)getCharacteristicWithPeripheral:(CBPeripheral *)peripheral serviceUUID:(NSString *)serviceUUID characteristicUUID:(NSString *)characteristicUUID
{
    // 将传入的 serviceUUID 和 characteristicUUID 字符串转换为 CBUUID 对象进行比较，
    // 避免因短 UUID（如 "FAA1"）与完整 128-bit UUID（如 "0000FAA1-0000-1000-8000-00805F9B34FB"）
    // 在字符串层面不一致而导致匹配失败的问题。
    // CBUUID 会自动将短 UUID 扩展为标准的 128-bit UUID，因此更适合做等价性比较。
    CBUUID *targetServiceUUID = [CBUUID UUIDWithString:serviceUUID];
    CBUUID *targetCharacteristicUUID = [CBUUID UUIDWithString:characteristicUUID];
    
    // 遍历外设已发现的服务列表
    for (CBService *service in peripheral.services)
    {
        // 判断服务 UUID 是否匹配
        if ([service.UUID isEqual:targetServiceUUID])
        {
            // 遍历该服务下的所有特征
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                // 判断特征 UUID 是否匹配
                if ([characteristic.UUID isEqual:targetCharacteristicUUID])
                {
                    return characteristic;
                }
            }
        }
    }
    
    // 未找到对应特征，返回 nil
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


/// 从服务数组中提取 serviceUUID 字符串并转换为 CBUUID 数组
- (NSArray<CBUUID *> *)extractServiceUUIDsFromServices:(NSArray<FLYService *> *)services
{
    if (services.count == 0)
    {
        return nil;
    }

    NSMutableArray<CBUUID *> *cbuuids = [NSMutableArray array];

    for (FLYService *service in services)
    {
        if (service.serviceUUID.length > 0)
        {
            CBUUID *uuid = [CBUUID UUIDWithString:service.serviceUUID];
            if (uuid)
            {
                [cbuuids addObject:uuid];
            }
        }
    }

    return cbuuids.count > 0 ? cbuuids : nil;
}


/// 从指定服务中提取 characteristicUUID 字符串并转换为 CBUUID 数组
- (NSArray<CBUUID *> *)extractCharacteristicUUIDsFromService:(FLYService *)service
{
    if (service.characteristicUUIDs.count == 0)
    {
        return nil;
    }

    NSMutableArray<CBUUID *> *cbuuids = [NSMutableArray array];

    for (NSString *uuidString in service.characteristicUUIDs)
    {
        if (uuidString.length > 0)
        {
            CBUUID *uuid = [CBUUID UUIDWithString:uuidString];
            if (uuid)
            {
                [cbuuids addObject:uuid];
            }
        }
    }

    return cbuuids.count > 0 ? cbuuids : nil;
}


/// 根据 CBService 找到对应的 FLYService
- (FLYService *)findFLYServiceFromPeripheral:(CBPeripheral *)peripheral cbService:(CBService *)service
{
    FLYConnectModel *connectModel = [self getConnectModelForPeripheral:peripheral];
    
    for (FLYService *tempService in connectModel.services)
    {
        // 使用 CBUUID 对象比较，避免短 UUID 和完整 UUID 字符串在格式上不一致而导致比较失败
        if ( [[CBUUID UUIDWithString:tempService.serviceUUID] isEqual:service.UUID] )
        {
            return tempService;
        }
    }
    
    return nil;
}


@end
