//
//  CBPeripheral+FLYExtension.m
//  BluetoothDemo
//
//  Created by fly on 2023/8/3.
//

#import "CBPeripheral+FLYExtension.h"
#import <objc/runtime.h>

@implementation CBPeripheral (FLYExtension)

-(void)setSubName:(NSString *)subName
{
    //关联对象 (给对象增加属性) (object:给哪个对象添加的属性 key:增加属性的名称 value:增加属性的值 policy:属性修饰符)
    objc_setAssociatedObject(self, "subName", subName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(NSString *)subName
{
    //获取关联对象 (object:获取哪个对象 key:增加属性的名称)
    return objc_getAssociatedObject(self, "subName");
}


@end


