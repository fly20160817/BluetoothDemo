//
//  FLYService.h
//  BluetoothDemo
//
//  Created by fly on 2025/7/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLYService : NSObject

@property (nonatomic, strong) NSString *serviceUUID;
@property (nonatomic, strong) NSArray<NSString *> *characteristicUUIDs;


+ (instancetype)serviceWithUUID:(NSString *)uuid characteristics:(NSArray<NSString *> *)characteristics;

@end

NS_ASSUME_NONNULL_END
