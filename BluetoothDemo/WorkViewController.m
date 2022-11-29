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

@end

@implementation WorkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)openLockClick:(UIButton *)sender
{
    [[FLYBluetoothHandler sharedHandler] openLock:@"HNTT-06123450a6ddeb" lockType:FLYLockTypeOTG params:nil success:^(NSString * _Nonnull lockId) {
        
        NSLog(@"开锁成功");
        
    } failure:^(NSString * _Nonnull lockId, NSError * _Nonnull error) {
        
        NSLog(@"开锁失败: %@", error);
        
    }];
}


@end
