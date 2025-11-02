# NNAspects

[![CI Status](https://img.shields.io/travis/17306472/NNAspects.svg?style=flat)](https://travis-ci.org/17306472/NNAspects)
[![Version](https://img.shields.io/cocoapods/v/NNAspects.svg?style=flat)](https://cocoapods.org/pods/NNAspects)
[![License](https://img.shields.io/cocoapods/l/NNAspects.svg?style=flat)](https://cocoapods.org/pods/NNAspects)
[![Platform](https://img.shields.io/cocoapods/p/NNAspects.svg?style=flat)](https://cocoapods.org/pods/NNAspects)

## 使用

```objc
/// 类方法 hook
+ (void)classMethodHook {
    [TestObject aspect_hookClassMethod:@selector(class_print:)
                               options:AspectPositionBefore
                            identifier:@"class_print_before"
                                 block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before class_print: %@ -> %@", s, params);
    }];
    [TestObject aspect_hookClassMethod:@selector(class_print:)
                               options:AspectPositionInstead
                            identifier:@"class_print_instead"
                                 block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead class_print: %@ -> %@", s, params);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    [TestObject aspect_hookClassMethod:@selector(class_print:)
                               options:AspectPositionAfter
                            identifier:@"class_print_after"
                                 block:^(AspectParams *params, NSString *s) {
        NSLog(@"---after class_print: %@ -> %@", s, params);
    }];
}

/// 实例方法 hook
+ (void)instanceMethodHook {
    [TestObject aspect_hookInstanceMethod:@selector(print1:)
                                  options:AspectPositionBefore
                               identifier:@"print1_before"
                                    block:^(AspectParams *params, NSString *s) {
        NSLog(@"---before %@: %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
    }];
    [TestObject aspect_hookInstanceMethod:@selector(print1:)
                                  options:AspectPositionInstead
                               identifier:@"print1_instead"
                                    block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead %@ %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
    
    __block NSString *oldRet;
    [TestObject aspect_hookInstanceMethod:@selector(print2:)
                                  options:AspectPositionInstead | AspectOptionAutomaticRemoval
                               identifier:@"print2_instead"
                                    block:^NSString * (AspectParams *params, NSString *s) {
        [params invokeAndGetOriginalReturnValue:&oldRet];
        return [oldRet stringByAppendingString:@" Instead"];
    }];
    
    // 实例对象 hook
    TestObject *objc = TestObject.new;
    [objc aspect_hookInstanceMethod:@selector(setName:) options:AspectPositionInstead identifier:@"setName_instead" block:^(AspectParams *params, NSString *s) {
        NSLog(@"---instead %@ %@ -> %@", params.slf,  NSStringFromSelector(params.sel), s);
        [params invokeAndGetOriginalReturnValue:NULL];
    }];
}
```
## Author

NeroXie, xyh30902@163.com

## License

NNAspects is available under the MIT license. See the LICENSE file for more info.
