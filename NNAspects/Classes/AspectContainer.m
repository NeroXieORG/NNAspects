//
//  AspectContainer.m
//  NNAspects
//
//  Created by NeroXie on 2022/10/17.
//

#import "AspectContainer.h"
#import <objc/runtime.h>

NSString * const AspectSubClassPrefix = @"NNAspectClass_";
NSString * const KVOClassPrefix = @"NSKVONotifying_";
NSString * const AspectSelectorPrefix = @"nn_aspect_sel_";


@interface AspectContainer ()

@property (nonatomic, strong) NSMutableArray<AspectInfo *> *beforeInfos;
@property (nonatomic, strong) AspectInfo *insteadInfo;
@property (nonatomic, strong) NSMutableArray<AspectInfo *> *afterInfos;
@property (nonatomic, copy) NSString *typeEncoding;
@property (nonatomic) IMP originalIMP;
@property (nonatomic) SEL sel;
@property (nonatomic) AspectIMP aspectIMP;
@property (nonatomic, assign) BOOL isInstanceHook;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSMethodSignature *signature;
// 原始方法签名对象的参数个数
@property (nonatomic, assign) NSUInteger argumentsCount;

@end

@implementation AspectContainer

AspectIMP _Nullable aspect_createAspectIMPForContainer(AspectContainer *container);

+ (instancetype)containerWithSelector:(SEL)sel {
    NSParameterAssert(sel);
    
    AspectContainer *container = AspectContainer.new;
    container.typeEncoding = nil;
    container.originalIMP = NULL;
    container.sel = sel;
    
    return container;
}

+ (instancetype)containerWithTypeEncoding:(NSString  *)typeEncoding originalIMP:(IMP)imp selector:(SEL)sel {
    NSParameterAssert(typeEncoding);
    NSParameterAssert(imp);
    NSParameterAssert(sel);
    
    AspectContainer *container = AspectContainer.new;
    container.typeEncoding = typeEncoding;
    container.originalIMP = imp;
    container.sel = sel;
    
    return container;
}

- (instancetype)init {
    if (self = [super init]) {
        _beforeInfos = @[].mutableCopy;
        _insteadInfo = nil;
        _afterInfos = @[].mutableCopy;
        _semaphore = dispatch_semaphore_create(1);
    }
    
    return self;
}

- (void)setTypeEncoding:(NSString *)typeEncoding {
    _typeEncoding = typeEncoding;
    _signature = typeEncoding ? [NSMethodSignature signatureWithObjCTypes:[typeEncoding UTF8String]]: nil;
    _argumentsCount = _signature.numberOfArguments;
}

- (void)setHookedCls:(Class)hookedCls {
    _hookedCls = hookedCls;
    _isInstanceHook = aspect_isIntanceHookCls(hookedCls);
}

- (BOOL)addInfo:(AspectInfo *)info {
    NSParameterAssert(info);
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    BOOL success = NO;
    NSUInteger position = AspectPosition(info.option);
    switch (position) {
        case AspectPositionBefore:
            if (![_identifiersFromInfos(_beforeInfos) containsObject:info.identifier]) {
                [_beforeInfos addObject:info];
                success = YES;
                break;
            }
        case AspectPositionInstead:
            _insteadInfo = info;
            success = YES;
            break;
        case AspectPositionAfter:
            if (![_identifiersFromInfos(_afterInfos) containsObject:info.identifier]) {
                [_afterInfos addObject:info];
                success = YES;
                break;
            }
        default:
            success = NO;
            break;
    }
    dispatch_semaphore_signal(_semaphore);
    return success;
}

- (BOOL)removeInfoForIdentifier:(AspectIdentifier)identifier {
    if ([self _removeInfoForIdentifier:identifier infos:_beforeInfos]) {
        return YES;
    }
    
    if (_insteadInfo && [_insteadInfo.identifier isEqualToString:identifier]) {
        _insteadInfo = nil;
        return YES;
    }
    
    if ([self _removeInfoForIdentifier:identifier infos:_afterInfos]) {
        return YES;
    }
    
    return NO;
}

- (NSArray<AspectIdentifier> *)allIdentifiers {
    NSMutableArray *allIdentifiers = [_identifiersFromInfos(_beforeInfos) mutableCopy];
    if (_insteadInfo) [allIdentifiers addObject:_insteadInfo.identifier];
    [allIdentifiers addObjectsFromArray:_identifiersFromInfos(_afterInfos)];
    
    return allIdentifiers;
}

- (AspectIMP)aspectIMP {
    if (!_aspectIMP) {
        _aspectIMP = aspect_createAspectIMPForContainer(self);
    }
    
    return _aspectIMP;
}

//- (NSString *)description {
//    
//}

#pragma mark - Private Method

- (BOOL)_removeInfoForIdentifier:(AspectIdentifier)identifier infos:(NSMutableArray<AspectInfo *> *)infos {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    BOOL result = NO;
    for (AspectInfo *info in infos.copy) {
        if ([info.identifier isEqualToString:identifier]) {
            [infos removeObject:info];
            result = YES;
            break;
        }
    }
    dispatch_semaphore_signal(_semaphore);
    return result;
}

#pragma mark - 内联函数

NS_INLINE NSArray<AspectIdentifier> * _identifiersFromInfos(NSArray<AspectInfo *> *infos) {
    NSMutableArray<AspectIdentifier> *identifiers = [NSMutableArray arrayWithCapacity:infos.count];
    for (AspectInfo *info in infos) {
        if (info.identifier) [identifiers addObject:info.identifier];
    }
    return identifiers.copy;
}

#pragma mark -

BOOL aspect_isIntanceHookCls(Class cls) {
    NSString *clsName = NSStringFromClass(cls);
    return [clsName hasPrefix:AspectSubClassPrefix] || [clsName hasPrefix:KVOClassPrefix];
}

void aspect_setAspectContainer(id obj, SEL key, AspectContainer *container) {
    NSCParameterAssert(obj);
    NSCParameterAssert(key);
    SEL associatedKey = NSSelectorFromString([AspectSelectorPrefix stringByAppendingString:NSStringFromSelector(key)]);
    objc_setAssociatedObject(obj, associatedKey, container, OBJC_ASSOCIATION_RETAIN);
}

AspectContainer * aspect_getAspectContainer(id obj, SEL key) {
    NSCParameterAssert(obj);
    NSCParameterAssert(key);
    SEL associatedKey = NSSelectorFromString([AspectSelectorPrefix stringByAppendingString:NSStringFromSelector(key)]);
    return objc_getAssociatedObject(obj, associatedKey);
}

@end

