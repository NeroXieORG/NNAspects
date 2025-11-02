//
//  AOPTesting.m
//  NNModule_Example
//
//  Created by NeroXie on 2025/10/29.
//  Copyright © 2025 17306472. All rights reserved.
//

#import "AOPTesting.h"
#import <NNAspects/Aspects.h>

@protocol AspectsTestProtocol <NSObject>

@required
- (void)print1:(NSString *)s;
- (NSString *)print2:(NSString *)s;
+ (void)class_print:(NSString *)s;

@end

@interface TestObject : NSObject <AspectsTestProtocol>

@property (nonatomic, copy) NSString *name;

@end

@implementation TestObject

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"change:%@",change);
}

- (void)setName:(NSString *)name {
    _name = name;
    NSLog(@"[Original setName:] %@", name);
}

- (void)print1:(NSString *)s {
    NSLog(@"%s -> %@", __func__, s);
}

- (NSString *)print2:(NSString *)s {
    NSLog(@"%s -> %@", __func__, s);
    return s;
}

+ (void)class_print:(NSString *)s {
    NSLog(@"%s -> %@", __func__, s);
}

@end

@implementation AOPTesting

#define removeAspect(CLASS, SEL) \
for (AspectIdentifier identifier in [CLASS aspect_allIdentifiersForKey:SEL]) { \
    [CLASS aspect_removeHookWithIdentifier:identifier forKey:SEL]; \
} \

+ (void)start {
    [TestObject aspect_hookClassMethod:@selector(class_print:) options:AspectPositionBefore identifier:@"class_print_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before class_print: %@ -> %@", s, params);
    }];
    [TestObject aspect_hookClassMethod:@selector(class_print:) options:AspectPositionInstead identifier:@"class_print_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead class_print: %@ -> %@", s, params);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    [TestObject aspect_hookClassMethod:@selector(class_print:) options:AspectPositionAfter identifier:@"class_print_after" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---after class_print: %@ -> %@", s, params);
    }];
    
    [TestObject aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionBefore identifier:@"print1_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    [TestObject aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionInstead identifier:@"print1_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead %@ %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    [TestObject aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionAfter identifier:@"print1_after" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---after %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    
    __block NSString *oldRet;
    [TestObject aspect_hookInstanceMethod:@selector(print2:) options:AspectPositionInstead | AspectOptionAutomaticRemoval identifier:@"print2_instead" block:^NSString * (AspectParams *params, NSString *s) {
        [params invokeAndGetOriginalReturnValue:&oldRet];
        return [oldRet stringByAppendingString:@" Instead"];
    }];
    
    
    NSLog(@"测试类方法 hook"); // hook class methods
    [TestObject class_print:@"NeroXie"];
    
    NSLog(@"测试实例方法 hook"); // hook instance methods
    TestObject *objc = [TestObject new];
    [objc print1:@"NeroXie"];
    
    NSLog(@"测试带返回值实例方法 hook");
    NSLog(@"%@", [objc print2:@"NeroXie"]);
    NSLog(@"%@", [objc print2:@"NeroXie"]);
    
    NSLog(@"测试先 hook class 后 hook instance"); //
    [objc aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionBefore identifier:@"print1_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instance before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    
    [objc aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionInstead identifier:@"print1_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instance instead %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    
    [objc print1:@"NeroXie"];
    
    NSLog(@"测试先 hook instance 后 hook class"); //
    removeAspect(TestObject, @selector(print1:))
    [TestObject aspect_hookInstanceMethod:@selector(print1:) options:AspectPositionBefore identifier:@"print1_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    
    [objc print1:@"NeroXie"];
    
    NSLog(@"测试恢复");
    removeAspect(objc, @selector(print1:))
    removeAspect(TestObject, @selector(print1:))
    [objc print1:@"NeroXie"];
    
    NSLog(@"测试先 KVO 后 AOP");
    objc = TestObject.new;
    [objc addObserver:objc forKeyPath:@"name" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [objc aspect_hookInstanceMethod:@selector(setName:) options:AspectPositionBefore identifier:@"setName_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    [TestObject aspect_hookInstanceMethod:@selector(setName:) options:AspectPositionInstead identifier:@"setName_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead %@ %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    objc.name = @"A1";
    removeAspect(objc, @selector(setName:))
    removeAspect(TestObject, @selector(setName:))
    [objc removeObserver:objc forKeyPath:@"name"];
    
    NSLog(@"测试先 AOP 后 KVO");
    [objc aspect_hookInstanceMethod:@selector(setName:) options:AspectPositionBefore identifier:@"setName_before" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    [TestObject aspect_hookInstanceMethod:@selector(setName:) options:AspectPositionInstead identifier:@"setName_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead %@ %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    [objc addObserver:objc forKeyPath:@"name" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    objc.name = @"A2";
    removeAspect(objc, @selector(setName:))
    removeAspect(TestObject, @selector(setName:))
    [objc removeObserver:objc forKeyPath:@"name"];
    
}

@end
