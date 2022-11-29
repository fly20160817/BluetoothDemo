//
//  FLYBluetoothHandler.m
//  BluetoothDemo
//
//  Created by fly on 2022/10/27.
//

#import "FLYBluetoothHandler.h"
#import "FLYBluetoothManager.h"

@interface FLYBluetoothHandler () < FLYBluetoothManagerDelegate >

@property (nonatomic, strong) NSString * lockId;
@property (nonatomic, assign) FLYLockType lockType;
@property (nonatomic, strong) NSDictionary * params;
@property (nonatomic, copy) SuccessBlock successBlock;
@property (nonatomic, copy) FailureBlock failureBlock;

@end

@implementation FLYBluetoothHandler

+ (instancetype)sharedHandler
{
    static FLYBluetoothHandler * _handler;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _handler = [[FLYBluetoothHandler alloc] init];
    });
    
    return _handler;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        [FLYBluetoothManager sharedManager].delegate = self;
        
    }
    return self;
}



#pragma mark - public methods

- (void)openLock:(NSString *)lockId lockType:(FLYLockType)lockType params:(nullable NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    self.lockId = lockId;
    self.lockType = lockType;
    self.params = params;
    self.successBlock = success;
    self.failureBlock = failure;
    
    
    [[FLYBluetoothManager sharedManager] scanAndConnect:lockId success:^(CBPeripheral * peripheral) {
        
        NSData * data = [self getOpenLockCommand];
        
        [[FLYBluetoothManager sharedManager] writeData:data peripheral:nil characteristicUUID:@"FF01"];
        
    } failure:^(NSError * error) {
        
        self.failureBlock(self.lockId, error);
    }];

   
}



#pragma mark - FLYBluetoothManagerDelegate

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( error )
    {
        self.failureBlock(self.lockId, error);
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( error )
    {
        return;
    }
    
    NSString * hexString = [FLYBluetoothManager convertDataToHexString:characteristic.value];
    
    
    // 不同锁、不同操作返回的长度可能不同
    if ( hexString.length == 4 )
    {
        NSString * code  = [hexString substringToIndex:2];
        NSString * state = [hexString substringWithRange:NSMakeRange(2, 2)];
        
        //OTG开锁   3401 34代表开锁，01代表成功，非01都是失败
        if ( code.intValue == 34 )
        {
            // 开锁成功
            if ( state.intValue == 01 )
            {
                // 请求接口，上报开锁记录
                //[self uploadUnlockRecordNetwork:self.params];
                
                self.successBlock(self.lockId);
            }
            // 开锁失败
            else
            {
                self.failureBlock(self.lockId, nil);
            }
        }
        //OTG关锁   4101 41代表开锁，01代表成功，非01都是失败
        else if ( code.intValue == 41 )
        {
            
        }
        
    }
    // 不同锁、不同操作返回的长度可能不同
    else if ( hexString.length == 6 )
    {
        
    }
    else
    {
        
    }
}



#pragma mark - OTG

// OTG的开锁指令
- (NSData *)openLockCommandWithOTG
{
    // 字符串 转 data
    NSData * data = [FLYBluetoothManager convertHexStringToData:@"343d0e9ef7b74e2d78248f208fbb6407b9"];

    return data;
}



#pragma mark - private methods

// 获取开锁指令
- (NSData *)getOpenLockCommand
{
    NSData * data;
    
    switch ( self.lockType )
    {
        case FLYLockTypeOTG:
        {
            data = [self openLockCommandWithOTG];
        }
            break;
            
        default:
            break;
    }
    
    return data;
}


@end
