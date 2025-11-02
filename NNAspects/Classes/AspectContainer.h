//
//  AspectContainer.h
//  NNAspects
//
//  Created by NeroXie on 2022/10/17.
//

#import <Foundation/Foundation.h>

#import "Aspects.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const AspectSubClassPrefix;
FOUNDATION_EXPORT NSString * const KVOClassPrefix;
FOUNDATION_EXPORT NSString * const AspectSelectorPrefix;

#pragma mark - Aspect Info

@interface AspectInfo : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 构造函数
/// - Parameters:
///   - option: 切面时机
///   - identifier: 切面标识符
///   - block: 执行切面的 block
+ (instancetype)infoWithOption:(AspectOptions)option identifier:(AspectIdentifier)identifier block:(id)block;
/// 执行切面的 block
- (id)block;
/// 切面时机
- (AspectOptions)option;
/// 切面标识符
- (AspectIdentifier)identifier;
/// 切面执行后自动删除
- (BOOL)automaticRemoval;

@end

/**
 切面容器类，每一个被 hook 的函数都有对应一个容器对象，主要作用：
 1. 保存某个被 hook 的函数的所有相关信息，如 IMP，SEL 等
 2. 维护 before / instead / after block的调用链；
 3. 提供 AspectIMP（统一中转 IMP）。
 */
@interface AspectContainer: NSObject

/// 原始方法执行前要调用的切面信息
@property (nonatomic, strong, readonly) NSArray<AspectInfo *> *beforeInfos;
/// 替换原始方法实现的切面信息
@property (nonatomic, strong, readonly, nullable) AspectInfo *insteadInfo;
/// 原始方法执行后要调用的切面信息
@property (nonatomic, strong, readonly) NSArray<AspectInfo *> *afterInfos;
/// 被 hook 的类，在对实例对象做 hook 操作时，这个值是 hook 动态生成的子类
@property (nonatomic, weak) Class hookedCls;
/// 原始类
@property (nonatomic, weak) Class statedCls;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 构造函数
/// - Parameters:
///   - typeEncoding: 原始方法类型编码
///   - imp: 原始方法 IMP
///   - sel: 原始方法 SEL
+ (instancetype)containerWithTypeEncoding:(NSString *)typeEncoding originalIMP:(IMP)imp selector:(SEL)sel;
///  构造函数
/// - Parameter sel: 原始方法 SEL
+ (instancetype)containerWithSelector:(SEL)sel;
/// 添加一个切面信息（前/后/替换），并返回是否成功
/// - Parameter info: 切面信息对象
- (BOOL)addInfo:(AspectInfo *)info;
/// 根据 identifier 删除某个切面信息
/// - Parameter identifier: 切面信息的 identifier
- (BOOL)removeInfoForIdentifier:(AspectIdentifier)identifier;
/// 返回当前切面容器所有的切面标识符
- (NSArray<AspectIdentifier> *)allIdentifiers;
/// 原始方法类型编码
- (NSString * _Nullable)typeEncoding;
/// 原始方法签名对象
- (NSMethodSignature *)signature;
/// 原始方法 SEL
- (SEL)sel;
/// 原始方法 IMP
- (IMP _Nullable)originalIMP;
/// 中转IMP，可以理解为原始方法新的入口，外部调用 -> aspectIMP -> beforeHooks -> originalIMP / insteadHook -> afterHooks
- (AspectIMP)aspectIMP;
/// 是否是针对单个对象的 hook
- (BOOL)isInstanceHook;

@end

///// 是否是实例对象 hook 动态产生的类
///// - Parameter cls: hook class
BOOL aspect_isIntanceHookCls(Class cls);

void aspect_setAspectContainer(id obj, SEL key, AspectContainer *container);

AspectContainer * _Nullable aspect_getAspectContainer(id obj, SEL key);

NS_ASSUME_NONNULL_END
