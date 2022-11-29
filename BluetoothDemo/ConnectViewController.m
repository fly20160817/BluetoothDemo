//
//  ConnectViewController.m
//  Bluetooth
//
//  Created by fly on 2022/10/19.
//

/*
    直接使用FLYBluetoothManager类来进行连接、读写。
    传一个蓝牙名称，搜索并自动连接。设置代理，需要用到哪些代理就写哪些。
 */


#import "ConnectViewController.h"
#import "FLYBluetoothManager.h"

@interface ConnectViewController () < FLYBluetoothManagerDelegate >

@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation ConnectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.textField.text = @"HNTT-06123450a6ddeb";
    
    [FLYBluetoothManager sharedManager].delegate = self;
}

- (IBAction)scanAndConnect:(UIButton *)sender
{
    [[FLYBluetoothManager sharedManager] scanAndConnect:self.textField.text success:^(CBPeripheral * _Nonnull peripheral) {
        
        NSLog(@"连接成功");
        
    } failure:^(NSError * _Nonnull error) {
        
        NSLog(@"连接失败：%@", error);
    }];
    
}

- (IBAction)writeData:(UIButton *)sender
{
    NSData * data = [FLYBluetoothManager  convertHexStringToData:@"343d0e9ef7b74e2d78248f208fbb6407b9"];

    [[FLYBluetoothManager sharedManager] writeData:data peripheral:nil characteristicUUID:@"FF01"];
}



#pragma mark - FLYBluetoothManagerDelegate

// 读取数据后的回调
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"data = %@", characteristic.value);
}




@end
