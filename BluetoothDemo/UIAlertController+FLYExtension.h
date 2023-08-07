//
//  UIAlertController+FLYExtension.h
//  FLYKit
//
//  Created by fly on 2021/4/6.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIAlertController (FLYExtension)


/// 快速创建
/// @param title 标题
/// @param message 内容
/// @param preferredStyle 风格
/// @param titles 选项按钮的名字
/// @param alerAction 点击事件 (index点击了第几个按钮，从0开始，从左往右)
+ (instancetype)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle titles:(NSArray *)titles alertAction:(void (^)(NSInteger index))alerAction;

/** 显示 */
- (void)show;

@end

NS_ASSUME_NONNULL_END
