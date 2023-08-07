//
//  UIAlertController+FLYExtension.m
//  FLYKit
//
//  Created by fly on 2021/4/6.
//

#import "UIAlertController+FLYExtension.h"

@implementation UIAlertController (FLYExtension)

+ (instancetype)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle titles:(NSArray *)titles alertAction:(void (^)(NSInteger index))alerAction
{
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:preferredStyle];
    
    [titles enumerateObjectsUsingBlock:^(NSString * btnTitle, NSUInteger idx, BOOL * _Nonnull stop) {
        
        UIAlertAction * action = [UIAlertAction actionWithTitle:btnTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
            !alerAction ?: alerAction(idx);
            
        }];
        
        [alertController addAction:action];
    }];
  
    return alertController;
}

- (void)show
{
    UIViewController * vc = [self getKeyWindow].rootViewController;
    [vc presentViewController:self animated:YES completion:nil];
}

- (UIWindow *)getKeyWindow
{
    NSArray * windows = [[UIApplication sharedApplication] windows];
    
    for ( UIWindow * window in windows )
    {
        if ( window.isKeyWindow )
        {
            return window;
        }
    }
    
    return nil;
}


@end
