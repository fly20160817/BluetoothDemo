//
//  NSData+FLYHex.m
//  FLYKit
//
//  Created by fly on 2023/6/5.
//

#import "NSData+FLYHex.h"

@implementation NSData (FLYHex)

// data转十六进制字符串
+ (NSString *)convertDataToHexString:(NSData *)data
{
    // 将NSData对象转换为指向无符号字符的指针
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    
    // 检查是否存在有效的数据
    if (!dataBuffer)
    {
        return @"";
    }
    
    // 创建一个可变字符串，用于存储转换后的十六进制字符串
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(data.length * 2)];
    
    // 遍历每个字节，并将其转换为两位的十六进制字符串
    for (NSUInteger i = 0; i < data.length; ++i)
    {
        //将每个字节转换为十六进制字符串
        NSString * string = [NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]];
        //追加到结果字符串中
        [hexString appendString:string];
    }
    
    return [hexString copy];
}


// 十六进制字符串转data
+ (NSData *)convertHexStringToData:(NSString *)hexString
{
    // 去除字符串中的空格和换行符
    /*
     1.空格和换行符在十六进制字符串中没有实际意义，它们只是为了增加可读性而添加的格式化字符。在转换过程中，我们只关注有效的十六进制字符。
     2.去除空格和换行符可以确保输入的十六进制字符串不包含任何非法字符。只有包含有效的十六进制字符（0-9、A-F或a-f）的字符串才能正确转换为NSData对象。
     3.如果不去除空格和换行符，那么转换过程中将会将它们作为无效字符处理，导致转换失败。
     */
    NSString *cleanedString = [[hexString stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    // 检查十六进制字符串长度是否为偶数 (十六进制表示一个字节需要使用两个字符。每个字节由8个二进制位组成，而每个十六进制字符表示4个二进制位。因此，有效的十六进制字符串长度应为偶数。)
    NSUInteger length = cleanedString.length;
    if (length % 2 != 0)
    {
        // 长度不符合要求，返回nil
        return nil;
    }
    
    // 创建一个可变的数据缓冲区
    NSMutableData *data = [NSMutableData dataWithCapacity:length/2];
    
    // 遍历十六进制字符串的字符并转换为字节
    for (NSUInteger i = 0; i < length; i += 2)
    {
        // 获取两个十六进制字符
        NSString *hex = [cleanedString substringWithRange:NSMakeRange(i, 2)];
        
        // 将十六进制字符转换为字节
        NSScanner *scanner = [NSScanner scannerWithString:hex];
        unsigned int byteValue;
        if ( ![scanner scanHexInt:&byteValue] )
        {
            // 转换失败，返回nil
            return nil;
        }
        
        // 将字节添加到数据缓冲区
        [data appendBytes:&byteValue length:1];
    }
    
    return [data copy];
}


/// data 转 string字符串
+ (NSString *)convertDataToString:(NSData *)data
{
    NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}


/// string字符串 转 data
+ (NSData *)convertStringToData:(NSString *)string
{
    NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return data;
}

@end
