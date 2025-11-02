//
//  ffi_function.h
//  NNAspects
//
//  Created by NeroXie on 2022/10/18.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "AspectContainer.h"
#import "ffi.h"

static void * AspectFFIKey = &AspectFFIKey;

@interface AspectInfo() {
@public
    id _block;
}

@end

@interface AspectParams()

+ (instancetype)paramsWithContainer:(AspectContainer *)container args:(void **)args;

@end

@interface AspectContainer ()

@property (nonatomic, strong) AspectInfo *insteadInfo;

- (NSUInteger)argumentsCount;

@end

void * aspect_getIMPForBlock(id block);

@interface AspectFFI: NSObject

@end

@implementation AspectFFI {
    ffi_cif _cif; // call interface
    ffi_cif _blockCif; // block call interface
    ffi_type **_args; // 参数类型数组
    ffi_type **_blockArgs; // block 参数类型数组
    ffi_closure *_closure; // 运行时动态生成函数（IMP）入口的结构体
}

- (void)dealloc {
    if (_closure != NULL) ffi_closure_free(_closure);
    if (_args != NULL) free(_args);
    if (_blockArgs != NULL) free(_blockArgs);
}

AspectIMP aspect_createAspectIMPForContainer(AspectContainer *container) {
    NSMethodSignature *signature = container.signature;
    ffi_type *returnType = _ffiTypeWithType(signature.methodReturnType);
    NSCAssert(returnType, @"can't find a ffi_type of %s", signature.methodReturnType);
    
    AspectFFI *aspect_ffi = _getFFIForAspectContainer(container);
    
    // 创建参数类型数组
    NSUInteger argumentsCount = container.argumentsCount;
    aspect_ffi->_args = malloc(sizeof(ffi_type *) * argumentsCount) ;
    for (int i = 0; i < argumentsCount; i++) {
        ffi_type* current_ffi_type = _ffiTypeWithType([signature getArgumentTypeAtIndex:i]);
        NSCAssert(current_ffi_type, @"can't find a ffi_type of %s", [signature getArgumentTypeAtIndex:i]);
        aspect_ffi->_args[i] = current_ffi_type;
    }
    
    // 创建 call interface
    if(ffi_prep_cif(&aspect_ffi->_cif, FFI_DEFAULT_ABI, (unsigned int)argumentsCount, returnType, aspect_ffi->_args) != FFI_OK) {
        NSCAssert(NO, @"OMG");
    }
    
    // 创建 block 参数类型数组
    aspect_ffi->_blockArgs = malloc(sizeof(ffi_type *) * argumentsCount);
    ffi_type *current_ffi_type_0 = _ffiTypeWithType("@?");
    aspect_ffi->_blockArgs[0] = current_ffi_type_0;
    ffi_type *current_ffi_type_1 = _ffiTypeWithType("@");
    aspect_ffi->_blockArgs[1] = current_ffi_type_1;
    for (int i = 2; i < argumentsCount; i++){
        ffi_type* current_ffi_type = _ffiTypeWithType([signature getArgumentTypeAtIndex:i]);
        aspect_ffi->_blockArgs[i] = current_ffi_type;
    }
    
    // 创建 block call interface
    if(ffi_prep_cif(&aspect_ffi->_blockCif, FFI_DEFAULT_ABI, (unsigned int)argumentsCount, returnType, aspect_ffi->_blockArgs) != FFI_OK) {
        NSCAssert(NO, @"OMG");
    }
    
    // 创建 aspectIMP 入口
    AspectIMP aspectIMP = NULL;
    aspect_ffi->_closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&aspectIMP);
    if (ffi_prep_closure_loc(aspect_ffi->_closure, &aspect_ffi->_cif, _ffi_function, (__bridge void *)(container), aspectIMP) != FFI_OK) {
        NSCAssert(NO, @"genarate hookIMP failed");
    }
    
    return aspectIMP;
}

ffi_type * _ffiTypeWithType(const char *c) {
    switch (c[0]) {
        case 'v':
            return &ffi_type_void;
        case 'c':
            return &ffi_type_schar;
        case 'C':
            return &ffi_type_uchar;
        case 's':
            return &ffi_type_sshort;
        case 'S':
            return &ffi_type_ushort;
        case 'i':
            return &ffi_type_sint;
        case 'I':
            return &ffi_type_uint;
        case 'l':
            return &ffi_type_slong;
        case 'L':
            return &ffi_type_ulong;
        case 'q':
            return &ffi_type_sint64;
        case 'Q':
            return &ffi_type_uint64;
        case 'f':
            return &ffi_type_float;
        case 'd':
            return &ffi_type_double;
        case 'F':
#if CGFLOAT_IS_DOUBLE
            return &ffi_type_double;
#else
            return &ffi_type_float;
#endif
        case 'B':
            return &ffi_type_uint8;
        case '^':
            return &ffi_type_pointer;
        case '*':
            return &ffi_type_pointer;
        case '@':
            return &ffi_type_pointer;
        case '#':
            return &ffi_type_pointer;
        case ':':
            return &ffi_type_pointer;
        case '{': {
            // http://www.chiark.greenend.org.uk/doc/libffi-dev/html/Type-Example.html
            ffi_type *type = malloc(sizeof(ffi_type));
            type->type = FFI_TYPE_STRUCT;
            NSUInteger size = 0;
            NSUInteger alignment = 0;
            NSGetSizeAndAlignment(c, &size, &alignment);
            type->alignment = alignment;
            type->size = size;
            while (c[0] != '=') ++c; ++c;
            
            NSPointerArray *pointArray = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory];
            while (c[0] != '}') {
                ffi_type *elementType = NULL;
                elementType = _ffiTypeWithType(c);
                if (elementType) {
                    [pointArray addPointer:elementType];
                    c = NSGetSizeAndAlignment(c, NULL, NULL);
                } else {
                    return NULL;
                }
            }
            NSInteger count = pointArray.count;
            ffi_type **types = malloc(sizeof(ffi_type *) * (count + 1));
            for (NSInteger i = 0; i < count; i++) {
                types[i] = [pointArray pointerAtIndex:i];
            }
            types[count] = NULL; // terminated element is NULL
            
            type->elements = types;
            return type;
        }
    }
    return NULL;
}



//#define _ffi_call_infos(infos) \
//for (NSUInteger i = 0; i < infos.count; i++) { \
///**/AspectInfo *info = infos[i]; \
///**/innerArgs[0] = &(info->_block); \
///**/ffi_call(&aspect_ffi->_blockCif, aspect_getIMPForBlock(info.block), NULL, innerArgs); \
///**/if (info.automaticRemoval) { \
///**//**/[(NSMutableArray *)infos removeObject:info]; \
///**//**/i--; \
///**/} \
//} \

#define REAL_STATED_CALSS_CONTAINER (statedClassContainer ?: hookedClassContainer)

/// libffi 在 Hook 方法时注册的回调函数，当被 hook 的方法被调用时，会进入这个函数。
/// - Parameters:
///   - cif: libffi 的调用接口描述（参数类型、返回值类型等）
///   - ret: 存放函数返回值的缓冲区
///   - args: 实际调用的参数数组（args[0] 通常是 self，args[1] 是 _cmd）
///   - userdata: 在注册 hook 时传入的上下文，这里是一个 NNHookInfoPool
NS_INLINE void _ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
    // 当前 hook 类的切面容器
    AspectContainer *hookedClassContainer = (__bridge AspectContainer *)userdata;
    AspectContainer *statedClassContainer = nil;
    AspectContainer *instanceContainer = nil;
    // 用来传递参数给 block 的新的参数数组
    void **innerArgs = alloca(hookedClassContainer.argumentsCount * sizeof(*innerArgs));
    // self 指针
    void **slf = args[0];
    
    // 当前 hook 类是针对实例对象的 hook，需要获取声明类的切面容器和实例对象的切面容器
    if (hookedClassContainer.isInstanceHook) {
        statedClassContainer = aspect_getAspectContainer(hookedClassContainer.statedCls, hookedClassContainer.sel);
        instanceContainer = aspect_getAspectContainer((__bridge id)(*slf), hookedClassContainer.sel);
    }
    
    AspectParams *params = [AspectParams paramsWithContainer:hookedClassContainer args:args];
    // block 调用时，第1个参数 AspectParams *
    innerArgs[1] = &params;
    // 复制参数到 innerArgs 中，跳过前两个参数，args[0] 是 self，args[1] 是 _cmd
    memcpy(innerArgs + 2, args + 2, (hookedClassContainer.argumentsCount - 2) * sizeof(*args));
    
    AspectFFI *aspect_ffi = _getFFIForAspectContainer(hookedClassContainer);
    
    // 执行 before hooks
    if (REAL_STATED_CALSS_CONTAINER) _ffi_call_infos(REAL_STATED_CALSS_CONTAINER.beforeInfos, aspect_ffi, innerArgs);
    if (instanceContainer) _ffi_call_infos(instanceContainer.beforeInfos, aspect_ffi, innerArgs);
    
    // 执行 instead hooks
    if (instanceContainer && instanceContainer.insteadInfo) {
        AspectInfo *insteadInfo = instanceContainer.insteadInfo;
        innerArgs[0] = &insteadInfo->_block;
        ffi_call(&aspect_ffi->_blockCif, aspect_getIMPForBlock(insteadInfo.block), ret, innerArgs);
        if (insteadInfo.automaticRemoval) {
            instanceContainer.insteadInfo = nil;
        }
    } else if (REAL_STATED_CALSS_CONTAINER && REAL_STATED_CALSS_CONTAINER.insteadInfo) {
        AspectInfo *insteadInfo = REAL_STATED_CALSS_CONTAINER.insteadInfo;
        innerArgs[0] = &insteadInfo->_block;
        ffi_call(&aspect_ffi->_blockCif, aspect_getIMPForBlock(insteadInfo.block), ret, innerArgs);
        if (insteadInfo.automaticRemoval) {
            REAL_STATED_CALSS_CONTAINER.insteadInfo = nil;
        }
    } else {
        /// 对 original IMP 做一个兼容处理，aspects 或 jspatch 这类库会把原始方法 IMP 替换为 _objc_msgForward，并执行相关的invacation.
        BOOL isForward = hookedClassContainer.originalIMP == _objc_msgForward
#if !defined(__arm64__)
        || hookedClassContainer.originalIMP == (IMP)_objc_msgForward_stret
#endif
        ;
        if (isForward) {
            [params invokeAndGetOriginalReturnValue:ret];
        } else {
            ffi_call(cif, (void (*)(void))hookedClassContainer.originalIMP, ret, args);
        }
    }
    
    // 执行 after hooks
    if (REAL_STATED_CALSS_CONTAINER) _ffi_call_infos(REAL_STATED_CALSS_CONTAINER.afterInfos, aspect_ffi, innerArgs);
    if (instanceContainer) _ffi_call_infos(instanceContainer.afterInfos, aspect_ffi, innerArgs);
}

NS_INLINE void _ffi_call_infos(NSArray<AspectInfo *> *infos, AspectFFI *aspect_ffi, void **innerArgs) {
    for (NSUInteger i = 0; i < infos.count; i++) {
        AspectInfo *info = infos[i];
        innerArgs[0] = &(info->_block);
        ffi_call(&aspect_ffi->_blockCif, aspect_getIMPForBlock(info.block), NULL, innerArgs);
        if (info.automaticRemoval) {
            [(NSMutableArray *)infos removeObject:info];
            i--;
        }
    }
}

NS_INLINE AspectFFI * _getFFIForAspectContainer(AspectContainer * container) {
    AspectFFI *ffi = objc_getAssociatedObject(container, AspectFFIKey);
    if (ffi) return ffi;
    
    ffi = [AspectFFI new];
    objc_setAssociatedObject(container, AspectFFIKey, ffi, OBJC_ASSOCIATION_RETAIN);
    
    return ffi;
}

@end

