//
//  WorkViewController.m
//  BluetoothDemo
//
//  Created by fly on 2022/11/29.
//


/*
    使用业务处理类FLYBluetoothHandler来进行操作，连接、读写、请求接口都在业务处理类里完成，完全隔离了FLYBluetoothManager类。
 */


#import "WorkViewController.h"
#import "FLYBluetoothHandler.h"

@interface WorkViewController ()
{
    NSString * _deviceName;
}
@end

@implementation WorkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    // 设备名：ESP32  特征：0001
    // 设备名：QJB2   特征： 写 36F5   读 36F6
    
    _deviceName = @"QJB2";
    
    
    [[FLYBluetoothHandler sharedHandler] bluetoothDidUpdateValueForCharacteristic:^(CBPeripheral * _Nonnull peripheral, CBCharacteristic * _Nonnull characteristic, NSError * _Nonnull error) {
        
        if ( [peripheral.name isEqualToString:self->_deviceName] || [peripheral.subName isEqualToString:self->_deviceName] )
        {
            NSLog(@"第二页_收到特征值更新通知 = %@, error = %@", characteristic, error);
        }
        
    }];

}


- (IBAction)openLockClick:(UIButton *)sender
{
    
    NSString * dateString = @"11open";
    NSData * data = [dateString dataUsingEncoding:NSUTF8StringEncoding];
    
    [[FLYBluetoothHandler sharedHandler] bluetoothWriteWithDeviceName:_deviceName data:data characteristicUUID:@"36F5" success:^(NSData * _Nullable data) {
        
        NSLog(@"第二页_写入成功");
        
    } failure:^(NSError * _Nonnull error) {
        
        NSLog(@"第二页_写入失败：%@", error);
        
    } progress:^(FLYBluetoothProgress progress) {
        
        NSLog(@"progress111 = %ld", (long)progress);
        
    }];
    
}
- (IBAction)kaisuo2:(UIButton *)sender
{
    [[FLYBluetoothHandler sharedHandler] bluetoothReadWithDeviceName:_deviceName characteristicUUID:@"36F6" success:^(NSData * _Nullable data) {
        
        NSLog(@"第二页_读取成功：%@", data);
        
    } failure:^(NSError * _Nonnull error) {
        
        NSLog(@"第二页_读取失败：%@", error);
        
    } progress:^(FLYBluetoothProgress progress) {
        
        NSLog(@"progress222 = %ld", (long)progress);
    }];
    
}


@end
