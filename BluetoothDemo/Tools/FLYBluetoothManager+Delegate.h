//
//  FLYBluetoothManager+Delegate.h
//  BluetoothDemo
//
//  Created by fly on 2025/7/25.
//

/**
 CBCentralManagerDelegate 和 CBPeripheralDelegate 的代理方法都在分类里实现。
 */

#import "FLYBluetoothManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLYBluetoothManager (Delegate) < CBCentralManagerDelegate, CBPeripheralDelegate >

@end

NS_ASSUME_NONNULL_END
