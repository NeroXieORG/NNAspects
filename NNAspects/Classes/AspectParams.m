//
//  AspectParams.m
//  NNFoundation
//
//  Created by NeroXie on 2022/10/17.
//

#import "AspectContainer.h"
#import <objc/runtime.h>

@implementation NSMethodSignature (ArgumentTypes)

- (NSArray *)argumentTypes {
    NSMutableArray *types = [NSMutableArray array];
    NSUInteger count = self.numberOfArguments;
    for (NSUInteger i = 0; i < count; ++i) {
        const char *type = [self getArgumentTypeAtIndex:i];
        [types addObject:[NSString stringWithUTF8String:type]];
    }
    return [types copy];
}

@end

@interface AspectParams ()

@property (nonatomic, strong) NSString *typeEncoding;
@property (nonatomic) SEL sel;
@property (nonatomic) IMP originalIMP;
@property (nonatomic) void **args;
@property (nonatomic) NSArray *argumentTypes;
@property (nonatomic) NSArray *arguments;

@end

@implementation AspectParams

+ (instancetype)paramsWithContainer:(AspectContainer *)container args:(void **)args {
    NSParameterAssert(container);
    NSParameterAssert(container.typeEncoding);
    NSParameterAssert(container.originalIMP);
    NSParameterAssert(args);
    
    
    AspectParams *params = AspectParams.new;
    params.typeEncoding = container.typeEncoding;
    params.originalIMP = container.originalIMP;
    params.sel = container.sel;
    params.args = args;
    params.argumentTypes = container.signature.argumentTypes;
    [params _genarateArguments];
    
    return params;
}

- (id)slf {
    void **slfPointer = _args[0];
    return (__bridge id)(*slfPointer);
}

- (void)invokeAndGetOriginalReturnValue:(void *)retLoc {
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:_typeEncoding.UTF8String];
    NSInteger count = signature.numberOfArguments;
    NSInvocation *originalInvocation = [NSInvocation invocationWithMethodSignature:signature];
    for (int i = 0; i < count; i ++) {
        [originalInvocation setArgument:_args[i] atIndex:i];
    }
    [originalInvocation invokeUsingIMP:_originalIMP];
    // 如果有返回值，通过 retLoc 指针获取返回值
    if (originalInvocation.methodSignature.methodReturnLength && !(retLoc == NULL)) {
        [originalInvocation getReturnValue:retLoc];
    }
}

#pragma - mark Private

- (void)_genarateArguments {
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:_argumentTypes.count];
    for (NSUInteger i = 2; i < _argumentTypes.count; i++) {
        id argument = [self _argumentWithType:_argumentTypes[i] index:i];
        [args addObject:argument ?: NSNull.null];
    }
    _arguments = [args copy];
}

- (id)_argumentWithType:(NSString *)type index:(NSUInteger)index {
    const char *argType = type.UTF8String;
    // Skip const type qualifier.
    if (argType[0] == _C_CONST) argType++;
    
#define WRAP_AND_RETURN(type) do { type val = 0; val = *((type *)_args[index]); return @(val); } while (0)
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        void **objPointer = _args[index];
        return (__bridge id)(*objPointer);
    } else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = *((SEL *)_args[index]);
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(bool)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        void **blockPointer = _args[index];
        __unsafe_unretained id block = (__bridge id)(*blockPointer);
        return [block copy];
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(argType, &valueSize, NULL);
        
        unsigned char valueBytes[valueSize];
        memcpy(valueBytes, _args[index], valueSize);
        
        return [NSValue valueWithBytes:valueBytes objCType:argType];
    }
    return nil;
#undef WRAP_AND_RETURN
}

@end
