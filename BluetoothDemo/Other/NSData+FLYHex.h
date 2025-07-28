//
//  NSData+FLYHex.h
//  FLYKit
//
//  Created by fly on 2023/6/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (FLYHex)


/// data 转 十六进制字符串
+ (NSString *)convertDataToHexString:(NSData *)data;

/// 十六进制字符串 转 data
+ (NSData *)convertHexStringToData:(NSString *)hexString;


/// data 转 string字符串 （内部按照UTF-8来转的）
+ (NSString *)convertDataToString:(NSData *)data;

/// string字符串 转 data （内部按照UTF-8来转的）
+ (NSData *)convertStringToData:(NSString *)string;


@end

NS_ASSUME_NONNULL_END
