//
//  ListViewController.m
//  Bluetooth
//
//  Created by fly on 2022/10/20.
//

/*
    扫描附近蓝牙，展示在页面上，需要连接哪个，点击链接即可。
 */


#import "ListViewController.h"
#import "FLYBluetoothManager.h"

@interface ListViewController ()  < FLYBluetoothManagerDelegate >

//存放扫描到的外围设备的数组
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> * peripheralArray;

@property (nonatomic, strong) CBPeripheral * peripheral;

@end

@implementation ListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    
    
    
    [[FLYBluetoothManager sharedManager] addDelegate:self];
    [[FLYBluetoothManager sharedManager] startScan];
}



#pragma mark - FLYBluetoothManagerDelegate

-(void)bluetoothManager:(FLYBluetoothManager *)manager didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    //记录扫描到的设备 (扫描是不断的循环去扫的)
    //如果没有添加过就添加
    if ( ![self.peripheralArray containsObject:peripheral] )
    {
        //判断蓝牙名字不为空
        if ( peripheral.name > 0 )
        {
            [self.peripheralArray addObject:peripheral];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // UI更新代码
                [self.tableView reloadData];
            });
        }
    }
}



#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.peripheralArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    CBPeripheral * peripheral = self.peripheralArray[indexPath.row];
    cell.textLabel.text = peripheral.name;
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CBPeripheral * peripheral = self.peripheralArray[indexPath.row];
    self.peripheral = peripheral;
    
    [[FLYBluetoothManager sharedManager] connectPeripheral:peripheral services:nil];
}


#pragma mark - FLYBluetoothManagerDelegate

-(void)bluetoothManager:(FLYBluetoothManager *)manager didConnectPeripheral:(CBPeripheral *)peripheral
{
    if ( ![self.peripheral.name isEqualToString:peripheral.name] )
    {
        return;
    }
    
    NSLog(@"第三页_连接成功");
}



#pragma mark - setters and getters

-(NSMutableArray *)peripheralArray
{
    if ( _peripheralArray == nil )
    {
        _peripheralArray = [NSMutableArray array];
    }
    return _peripheralArray;
}


@end



