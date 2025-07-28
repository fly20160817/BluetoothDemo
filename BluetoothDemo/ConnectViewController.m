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

@property (weak, nonatomic) IBOutlet UITextField *nameTF;
@property (weak, nonatomic) IBOutlet UITextField *uuidTF;

@end

@implementation ConnectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.nameTF.text = @"ecdb70c87c5b";
    self.uuidTF.text = @"AF02";
    
    
    [[FLYBluetoothManager sharedManager] addDelegate:self];
}

- (IBAction)scanAndConnect:(UIButton *)sender
{
    FLYService * service = [FLYService serviceWithUUID:@"FAA0" characteristics:@[@"FAA1", @"FAA2"]];

    [[FLYBluetoothManager sharedManager] scanAndConnect:self.nameTF.text services:@[service] timeout:0];
}

- (IBAction)writeData:(UIButton *)sender
{
    NSString * dateString = @"5506";
    NSData * data = [dateString dataUsingEncoding:NSUTF8StringEncoding];
    
    
    [[FLYBluetoothManager sharedManager] writeWithDeviceName:self.nameTF.text data:data serviceUUID:@"FAA0" characteristicUUID:self.uuidTF.text];
}



#pragma mark - FLYBluetoothManagerDelegate

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( ![peripheral.name isEqualToString:self.nameTF.text] )
    {
        return;
    }
    
    
    if ( error )
    {
        NSLog(@"第一页_写入失败，characteristic.UUID = %@， error = %@", characteristic.UUID.UUIDString, error);
    }
    else
    {
        NSLog(@"第一页_写入成功，characteristic.UUID = %@", characteristic.UUID.UUIDString);
    }
    
}


@end

