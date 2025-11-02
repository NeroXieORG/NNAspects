//
//  NNAspects.h
//  NNAspects
//
//  Created by NeroXie on 2022/10/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * AspectIdentifier;

typedef void * AspectIMP;

#pragma mark - enum

/// 切面时机
typedef NS_OPTIONS(NSInteger, AspectOptions) {
    AspectPositionAfter = 0,     // 在原始方法执行后生效（默认）
    AspectPositionInstead = 1,   // 替换原始方法
    AspectPositionBefore = 2,    // 在原始方法执行前生效
    AspectOptionAutomaticRemoval = 1 << 3, // 只执行一次
    AspectOptionWeakCheckSignature = 1 << 16, // 宽松检查选项，仅当 AspectPositionInstead 启用时才会检查返回类型，启用 AspectOptionWeakCheckSignature 后，仅检查第一个参数类型和返回类型。
};

/// 切面位置掩码 0x07, option & AspectPositionFilter 后可以屏蔽掉高位运算，仅保留低 3 位的值，用来判断切面的位置。
#define AspectPositionFilter 0x07

#define AspectPosition(option) option & AspectPositionFilter

/// 切面结果枚举
typedef NS_ENUM(NSInteger, AspectResult) {
    AspectResultSuccess = 1,
    AspectResultErrorMethodNotFound = -1, // hook 方法不存在
    AspectResultErrorBlockNotMatched = -2, // block 与 hook 方法 不匹配
    AspectResultErrorIDExisted = -3, //
    AspectResultOther = -4,
};

/// 切面回调参数体，block 回调中的第一个参数
@interface AspectParams: NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// self 指针
- (id)slf;
/// 方法 SEL
- (SEL)sel;
/// 方法参数列表
- (NSArray *)arguments;
/// 方法类型编码
- (NSString *)typeEncoding;
/// 执行原始方法并获取返回值
/// - Parameter retLoc: 原始返回值的指针
- (void)invokeAndGetOriginalReturnValue:(void * _Nullable)retLoc;

@end

#pragma mark - AOP 接口

@interface NSObject (Aspects)

#pragma mark - 指定类

/// 指定类 hook 实例方法
/// - Parameters:
///   - sel: 实例方法 SEL
///   - options: hook 时机
///   - identifier: hook 标识符
///   - block: 回调 block，block的第一个参数必须是 AspectParams *，即 ^(AspectParams *params, id 原始方法参数1, ...) {}
+ (AspectResult)aspect_hookInstanceMethod:(SEL)sel
                                  options:(AspectOptions)options
                               identifier:(AspectIdentifier)identifier
                                    block:(id)block;

/// 指定类 hook 类方法
/// - Parameters:
///   - sel: 类方法 SEL
///   - options: 切面时机
///   - identifier: 切面标识符
///   - block: 回调 block，block的第一个参数必须是 AspectParams *，即 ^(AspectParams *params, id 原始方法参数1, ...) {}
+ (AspectResult)aspect_hookClassMethod:(SEL)sel
                               options:(AspectOptions)options
                            identifier:(AspectIdentifier)identifier
                                 block:(id)block;

/// 获取方法所有的切面标识符
/// - Parameter key: 方法 SEL
+ (NSArray<AspectIdentifier> *)aspect_allIdentifiersForKey:(SEL)key;

/// 删除切面
/// - Parameters:
///   - identifier: hook 标识符
///   - key: 方法 SEL
+ (BOOL)aspect_removeHookWithIdentifier:(AspectIdentifier)identifier forKey:(SEL)key;

#pragma mark - 指定对象

/// 指定对象 hook 实例方法
/// - Parameters:
///   - sel: 实例方法 SEL
///   - options: hook 时机
///   - identifier: hook 标识符
///   - block: 回调 block，block的第一个参数必须是 AspectParams *，即 ^(AspectParams *params, id 原始方法参数1, ...) {}
- (AspectResult)aspect_hookInstanceMethod:(SEL)sel
                                    options:(AspectOptions)options
                                 identifier:(AspectIdentifier)identifier
                                      block:(id)block;

/// 获取某个方法所有 hook 切面的标识符
/// - Parameter key: 方法 SEL
- (NSArray<AspectIdentifier> *)aspect_allIdentifiersForKey:(SEL)key;

/// 删除 hook 切面
/// - Parameters:
///   - identifier: hook 标识符
///   - key: 方法 SEL
- (BOOL)aspect_removeHookWithIdentifier:(AspectIdentifier)identifier forKey:(SEL)key;

@end

NS_ASSUME_NONNULL_END
