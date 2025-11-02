//
//  NSObject+Aspects.m
//  NNAspects
//
//  Created by NeroXie on 2022/10/17.
//

#import "Aspects.h"
#import <objc/runtime.h>
#import "AspectContainer.h"

static void *AspectSubClassKey = &AspectSubClassKey;

@implementation NSObject (Aspects)

+ (AspectResult)aspect_hookInstanceMethod:(SEL)sel options:(AspectOptions)options identifier:(AspectIdentifier)identifier block:(id)block {
    return _hookMethod(self, sel, options, identifier, block);
}

+ (AspectResult)aspect_hookClassMethod:(SEL)sel options:(AspectOptions)options identifier:(AspectIdentifier)identifier block:(id)block {
    return _hookMethod(object_getClass(self), sel, options, identifier, block);
}

+ (NSArray<AspectIdentifier> *)aspect_allIdentifiersForKey:(SEL)key {
    NSMutableArray *mArray = @[].mutableCopy;
    @synchronized(self) {
        [mArray addObjectsFromArray:_getAllIdentifiers(self, key)];
        [mArray addObjectsFromArray:_getAllIdentifiers(object_getClass(self), key)];
    }
    return [mArray copy];
}

+ (BOOL)aspect_removeHookWithIdentifier:(AspectIdentifier)identifier forKey:(SEL)key {
    BOOL hasRemoved = NO;
    @synchronized(self) {
        AspectContainer *container = aspect_getAspectContainer(self, key);
        if ([container removeInfoForIdentifier:identifier]) hasRemoved = YES;
        
        container = aspect_getAspectContainer(object_getClass(self), key);
        if ([container removeInfoForIdentifier:identifier]) hasRemoved = YES;
    }
    
    return hasRemoved;
}

- (AspectResult)aspect_hookInstanceMethod:(SEL)sel options:(AspectOptions)options identifier:(AspectIdentifier)identifier block:(id)block {
    @synchronized(self) {
        Class subClass = _getSubClass(self);
        if (!subClass) return AspectResultOther;
        
        AspectResult hookMethodResult = _hookMethod(subClass, sel, options, identifier, block);
        if (hookMethodResult != AspectResultSuccess) return hookMethodResult;
        
        _setSubClass(self, subClass);
        
        AspectContainer *instanceContainer = aspect_getAspectContainer(self, sel);
        if (!instanceContainer) {
            // 生成实例的容器对象不需要 typeEncoding IMP 等字段，在 FFI 中只认 class 的容器
            instanceContainer = [AspectContainer containerWithSelector:sel];
            aspect_setAspectContainer(self, sel, instanceContainer);
        }
        
        AspectInfo *info = [AspectInfo infoWithOption:options identifier:identifier block:block];
        return [instanceContainer addInfo:info] ? AspectResultSuccess :  AspectResultErrorIDExisted;
    }
}

- (NSArray<AspectIdentifier> *)aspect_allIdentifiersForKey:(SEL)key {
    @synchronized(self) {
        return _getAllIdentifiers(self, key);
    }
}

- (BOOL)aspect_removeHookWithIdentifier:(AspectIdentifier)identifier forKey:(SEL)key {
    BOOL hasRemoved = NO;
    @synchronized(self) {
        AspectContainer *container = aspect_getAspectContainer(self, key);
        hasRemoved = [container removeInfoForIdentifier:identifier];
    }
    
    return hasRemoved;
}

#pragma mark - 内联函数

NSMethodSignature * aspect_getMethodSignatureForBlock(id block);

NS_INLINE AspectResult _hookMethod(Class hookedCls, SEL sel, AspectOptions options, AspectIdentifier identifier, id block) {
    NSCParameterAssert(hookedCls);
    NSCParameterAssert(sel);
    NSCParameterAssert(identifier);
    NSCParameterAssert(block);
    
    // 1. 查询原始方法是否存在
    Method method = class_getInstanceMethod(hookedCls, sel);
    NSCAssert(method, @"SEL (%@) doesn't has a imp in Class (%@) originally", NSStringFromSelector(sel), hookedCls);
    if (!method) return AspectResultErrorMethodNotFound;
    
    // 2. 匹配原始方法与 block 的签名对象是否一致
    const char * typeEncoding = method_getTypeEncoding(method);
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
    NSMethodSignature *blockSignature =  aspect_getMethodSignatureForBlock(block);
    if (!_isMatched(methodSignature, blockSignature, options, hookedCls, sel, identifier)) {
        return AspectResultErrorBlockNotMatched;
    }
    
    IMP originalIMP = method_getImplementation(method);
    // 同步锁保护类级 Hook，防止多线程同时 Hook 同一个类或同一个 selector 时发生竞态。
    @synchronized(hookedCls) {
        // 先 hook class 后 hook instance 的情况下，method_getImplementation 的 IMP 其实是已经被替换过的
        // 真正的 originalIMP 放在声明类中的切面容器中
        Class realClass = _getRealClass(hookedCls);
        AspectContainer *realClassContainer = aspect_getAspectContainer(realClass, sel);
        if (realClassContainer) {
            originalIMP = realClassContainer.originalIMP;
        }
        // 3. 创建切面容器对象
        AspectContainer *container = aspect_getAspectContainer(hookedCls, sel);
        if (!container) {
            NSString *typeEncodingString = [NSString stringWithUTF8String:typeEncoding];
            container = [AspectContainer containerWithTypeEncoding:typeEncodingString originalIMP:originalIMP selector:sel];
            container.hookedCls = hookedCls;
            container.statedCls = [hookedCls class];
            IMP aspectIMP = container.aspectIMP;
            if (!class_addMethod(hookedCls, sel, aspectIMP, typeEncoding)) {
                class_replaceMethod(hookedCls, sel, aspectIMP, typeEncoding);
            }
            
            aspect_setAspectContainer(hookedCls, sel, container);
        }
        
        if (aspect_isIntanceHookCls(hookedCls)) {
            return AspectResultSuccess;
        } else {
            AspectInfo *info = [AspectInfo infoWithOption:options identifier:identifier block:block];
            return [container addInfo:info] ? AspectResultSuccess :  AspectResultErrorIDExisted;
        }
    }
}

NS_INLINE NSArray<AspectIdentifier> * _getAllIdentifiers(id obj, SEL key) {
    NSCParameterAssert(obj);
    NSCParameterAssert(key);
    AspectContainer *container = aspect_getAspectContainer(obj, key);
    return container.allIdentifiers;
}

NS_INLINE BOOL _isMatched(NSMethodSignature *methodSignature, NSMethodSignature *blockSignature, AspectOptions options, Class cls, SEL sel, AspectIdentifier identifier) {
    // 默认为 strictCheck = YES，即严格检查
    BOOL strictCheck = ((options & AspectOptionWeakCheckSignature) == 0);
    
    // 严格检查时，先确认参数个数
    if (strictCheck && methodSignature.numberOfArguments != blockSignature.numberOfArguments) {
        NSCAssert(NO, @"count of arguments isn't equal. Class: (%@), SEL: (%@), Identifier: (%@)", cls, NSStringFromSelector(sel), identifier);
        return NO;
    };
    
    // 检查第一个参数类型
    const char *firstArgumentType = [blockSignature getArgumentTypeAtIndex:1];
    // block 特定规则：第一个参数必须是对象类型，
    if (!firstArgumentType || firstArgumentType[0] != '@') {
        NSCAssert(NO, @"argument 1 should be object type. Class: (%@), SEL: (%@), Identifier: (%@)", cls, NSStringFromSelector(sel), identifier);
        return NO;
    }
    
    // 严格模式下从第二个参数依次进行比较
    if (strictCheck) {
        for (NSInteger i = 2; i < methodSignature.numberOfArguments; i++) {
            const char *methodType = [methodSignature getArgumentTypeAtIndex:i];
            const char *blockType = [blockSignature getArgumentTypeAtIndex:i];
            if (!methodType || !blockType || methodType[0] != blockType[0]) {
                NSCAssert(NO, @"argument (%zd) type isn't equal. Class: (%@), SEL: (%@), Identifier: (%@)", i, cls, NSStringFromSelector(sel), identifier);
                return NO;
            }
        }
    }
    
    // 如果是 Instead，需要检查返回值类型，Before / After 类型的 hook 均不关心返回值。
    if ((AspectPosition(options)) == AspectPositionInstead) {
        const char *methodReturnType = methodSignature.methodReturnType;
        const char *blockReturnType = blockSignature.methodReturnType;
        if (!methodReturnType || !blockReturnType || methodReturnType[0] != blockReturnType[0]) {
            NSCAssert(NO, @"return type isn't equal. Class: (%@), SEL: (%@), Identifier: (%@)", cls, NSStringFromSelector(sel), identifier);
            return NO;
        }
    }
    
    return YES;
}

/// 获取定义的声明类
/// - Parameter cls: 声明类/派生类
NS_INLINE Class _getRealClass(Class cls) {
    NSString *clsName = NSStringFromClass(cls);
    if ([clsName hasPrefix:AspectSubClassPrefix]) {
        return NSClassFromString([clsName substringFromIndex:AspectSubClassPrefix.length]);
    } else if ([clsName hasPrefix:KVOClassPrefix]) {
        return NSClassFromString([clsName substringFromIndex:KVOClassPrefix.length]);
    } else {
        return cls;
    }
}

NS_INLINE void _setSubClass(id object, Class subClass) {
    if (!objc_getAssociatedObject(object, AspectSubClassKey)) {
        object_setClass(object, subClass);
        objc_setAssociatedObject(object, AspectSubClassKey, subClass, OBJC_ASSOCIATION_ASSIGN);
    }
}

NS_INLINE Class _getSubClass(id object) {
    Class subClass = objc_getAssociatedObject(object, AspectSubClassKey);
    if (subClass) return subClass;
    
    Class isaClass = object_getClass(object);
    NSString *isaClassName = NSStringFromClass(isaClass);
    if ([isaClassName hasPrefix:KVOClassPrefix]) {
        return isaClass;
    } else {
        const char *subclassName = [AspectSubClassPrefix stringByAppendingString:isaClassName].UTF8String;
        subClass = objc_getClass(subclassName);
        if (!subClass) {
            subClass = objc_allocateClassPair(isaClass, subclassName, 0);
            NSCAssert(subClass, @"Class %s allocate failed!", subclassName);
            if (!subClass) return nil;
            
            objc_registerClassPair(subClass);
            Class realClass = [object class];
            _hookGetClassMessage(subClass, realClass);
            _hookGetClassMessage(object_getClass(subClass), realClass);
        }
    }
    
    return subClass;
}

NS_INLINE void _hookGetClassMessage(Class class, Class retClass) {
    Method method = class_getInstanceMethod(class, @selector(class));
    IMP newIMP = imp_implementationWithBlock(^(id self) {
        return retClass;
    });
    class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

@end
