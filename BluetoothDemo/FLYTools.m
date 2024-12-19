//
//  FLYTools.m
//  FLYKit
//
//  Created by fly on 2021/8/11.
//

#import "FLYTools.h"

@implementation FLYTools


/**
 * 本地化字符串，并支持格式化。
 *
 * 该函数首先根据提供的键（key）从本地化文件中获取对应的字符串，然后
 * 使用可变参数列表对字符串进行格式化。如果本地化字符串中包含格式占位符
 * （例如 %@、%d 等），可变参数列表中的值将替换这些占位符。
 *
 * @param key 需要本地化的字符串键。该键将用于从 Localizable.strings 文件中获取对应的值。
 * @param ... 可变参数列表，用于格式化字符串。可以传递多个参数，这些参数将按顺序替换字符串中的占位符。
 *
 * @return 本地化并格式化后的字符串。如果没有找到对应的本地化字符串，返回键本身。
 */
NSString* FLYLocalizedString(NSString *key, ...) {
    // 从本地化文件中获取对应的字符串。如果没有找到，则返回键本身。
    NSString *localizedString = NSLocalizedString(key, nil);
    
    // 初始化可变参数列表。
    va_list args;
    va_start(args, key);
    
    // 使用可变参数对本地化字符串进行格式化。
    NSString *formattedString = [[NSString alloc] initWithFormat:localizedString arguments:args];
    
    // 结束可变参数的处理。
    va_end(args);
    
    // 返回格式化后的字符串。
    return formattedString;
    
    /**
     调用示例：
     
     1. NSString *simpleString = LocalizedString(@"主页");
     
     2. NSString *productName = self.productModel.productName ?: @"";
        NSString *message = LocalizedString(@"当前没有已配对的%@蓝牙设备", productName);
     */
}


@end
