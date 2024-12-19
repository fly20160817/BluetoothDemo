//
//  FLYTools.h
//  FLYKit
//
//  Created by fly on 2021/8/11.
//


#import <UIKit/UIKit.h>


// 根据 key 获取本地化字符串，并支持格式化。
#define LS(key, ...) FLYLocalizedString(key, ##__VA_ARGS__)


NS_ASSUME_NONNULL_BEGIN

@interface FLYTools : NSObject


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
NSString* FLYLocalizedString(NSString *key, ...);


@end

NS_ASSUME_NONNULL_END
