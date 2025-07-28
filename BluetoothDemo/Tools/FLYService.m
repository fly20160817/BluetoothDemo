//
//  FLYService.m
//  BluetoothDemo
//
//  Created by fly on 2025/7/24.
//

#import "FLYService.h"

@implementation FLYService

+ (instancetype)serviceWithUUID:(NSString *)uuid characteristics:(NSArray<NSString *> *)characteristics
{
    FLYService *service = [[FLYService alloc] init];
    service.serviceUUID = uuid;
    service.characteristicUUIDs = characteristics;
    return service;
}

@end
