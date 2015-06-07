//
//  DWURecyclingAlert.m
//  RecyclingAlert
//
//  Created by Di Wu on 6/7/15.
//  Copyright (c) 2015 Di Wu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UITableViewCell.h>
#import "UIView+DWURecyclingAlert.h"
#import <QuartzCore/CALayer.h>

#define DWU_PROPERTY(propName) NSStringFromSelector(@selector(propName))

// http://www.mikeash.com/pyblog/friday-qa-2010-01-29-method-replacement-for-fun-and-profit.html
static BOOL dwu_replaceMethodWithBlock(Class c, SEL origSEL, SEL newSEL, id block) {
    if ([c instancesRespondToSelector:newSEL]) return YES; // Selector already implemented, skip silently.
    
    Method origMethod = class_getInstanceMethod(c, origSEL);
    
    // Add the new method.
    IMP impl = imp_implementationWithBlock(block);
    if (!class_addMethod(c, newSEL, impl, method_getTypeEncoding(origMethod))) {
        return NO;
    }else {
        Method newMethod = class_getInstanceMethod(c, newSEL);
        
        // If original doesn't implement the method we want to swizzle, create it.
        if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(origMethod))) {
            class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(newMethod));
        }else {
            method_exchangeImplementations(origMethod, newMethod);
        }
    }
    return YES;
}

static void dwu_markAllSubviewsAsRecycled(UITableViewCell *_self) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (UIView *view in _self.contentView.subviews) {
            view.dwuRecyclingCount = @(1);
        }
    });
}

static void dwu_checkNonRecycledSubviews(UITableViewCell *_self) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (UIView *view in _self.contentView.subviews) {
            NSNumber *recyclingCount = view.dwuRecyclingCount;
            if (!recyclingCount) {
                view.dwuRecyclingCount = @(1);
                view.layer.borderColor = [[UIColor redColor] CGColor];
                view.layer.borderWidth = 5.0;
            } else {
                view.layer.borderColor = [[UIColor clearColor] CGColor];
                view.layer.borderWidth = 0.0;
            }
        }
    });
}

#if DEBUG
__attribute__((constructor)) static void DWURecyclingAlert(void) {
    @autoreleasepool {
        NSString *selStr = DWU_PROPERTY(prepareForReuse);
        SEL selector = NSSelectorFromString(selStr);
        SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UITableViewCell.class, selector, newSelector, ^(__unsafe_unretained UITableViewCell *_self) {
            ((void ( *)(id, SEL))objc_msgSend)(_self, newSelector);
            dwu_checkNonRecycledSubviews(_self);
        });
        selStr = DWU_PROPERTY(initWithStyle:reuseIdentifier:);
        selector = NSSelectorFromString(selStr);
        newSelector = NSSelectorFromString([NSString stringWithFormat:@"dwu_%@", selStr]);
        dwu_replaceMethodWithBlock(UITableViewCell.class, selector, newSelector, (id)^(__unsafe_unretained UITableViewCell *_self, NSInteger arg1, __unsafe_unretained id arg2) {
            dwu_markAllSubviewsAsRecycled(_self);
            return ((id ( *)(id, SEL, NSInteger, id))objc_msgSend)(_self, newSelector, arg1, arg2);
        });
    }
}
#endif