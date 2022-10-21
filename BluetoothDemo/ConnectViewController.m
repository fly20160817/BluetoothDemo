//
//  ConnectViewController.m
//  Bluetooth
//
//  Created by fly on 2022/10/19.
//


// 传一个蓝牙名称，搜索并自动连接。设置代理，需要用到哪些代理就写哪些。


#import "ConnectViewController.h"
#import "FLYBluetoothManager.h"

@interface ConnectViewController () < FLYBluetoothManagerDelegate >

@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation ConnectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.textField.text = @"ICIN_22a9e56501c8";
    
    [FLYBluetoothManager sharedManager].delegate = self;
}

- (IBAction)scanAndConnect:(UIButton *)sender
{
    [[FLYBluetoothManager sharedManager] scanAndConnect:self.textField.text];
}

- (IBAction)writeData:(UIButton *)sender
{
    NSData * data = [FLYBluetoothManager  convertHexStringToData:@"343d0e9ef7b74e2d78248f208fbb6407b9"];
        
    [[FLYBluetoothManager sharedManager] writeData:data peripheral:nil characteristicUUID:@"FFF1"];
}



#pragma mark - FLYBluetoothManagerDelegate

// 写入数据后的回调
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"---写入数据后的回调");
}



@end
