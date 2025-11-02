//
//  NNBlockSignature.h
//  Pods
//
//  Created by NeroXie on 2022/10/18.
//

#import <Foundation/Foundation.h>

/** 参考 https://clang.llvm.org/docs/Block-ABI-Apple.html */

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // 有拷贝（copy）/销毁（dispose）函数
    BLOCK_HAS_SIGNATURE  =    (1 << 30)  // 说明有签名
};

/*
 block 描述体内存结构大致长这样
 
 struct Block_descriptor_1 {
 unsigned long int reserved;     // NULL
 unsigned long int size;         // sizeof(struct Block_literal_1)
 // optional helper functions
 void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
 void (*dispose_helper)(void *src);             // IFF (1<<25)
 // required ABI.2010.3.16
 const char *signature;                         // IFF (1<<30)
 }
 */

// 标识符宏
#define BLOCK_DESCRIPTOR_1 1
struct Block_descriptor_1 {
    unsigned long int reserved;
    unsigned long int size;
    // requires BLOCK_HAS_COPY_DISPOSE
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;
};

// block 结构体
struct Block_layout {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    volatile int flags; // 标志位，说明 block 类型、是否有签名、是否有 copy/dispose 等
    int reserved;
    void (*invoke)(void *, ...); // block 的实际执行函数（调用入口）
    struct Block_descriptor_1 *descriptor; // 指向描述符，描述block额外信息（大小、签名、拷贝/销毁函数）
    // imported variables
};

/// 获取 block 的方法签名对象
/// - Parameter block: 任意 block 对象
/// - Returns: 对应的 NSMethodSignature，如果无法解析则返回 nil
NSMethodSignature * aspect_getMethodSignatureForBlock(id block) {
    struct Block_layout *layout = (__bridge void *)block;
    // 通过偏移量计算查看是否有签名函数，无返回 nil
    if (!(layout->flags & BLOCK_HAS_SIGNATURE)) {
        return nil;
    }
    // 跳过 Block_descriptor 的reserved 和 size 字段到后续区域
    void *descRef = layout->descriptor;
    descRef += 2 * sizeof(unsigned long int);
    
    // 如果有 copy/dispose 函数，再跳过这两个函数指针
    if (layout->flags & BLOCK_HAS_COPY_DISPOSE) {
        descRef += 2 * sizeof(void *);
    }
    
    if (!descRef) return nil;
    // 取出它所指向的签名 C 字符串，生成签名对象并返回
    const char *signature = (*(const char **)descRef);
    return [NSMethodSignature signatureWithObjCTypes:signature];
}

/// 获取 block 的 IMP
/// - Parameter block: 任意 block 对象
void * aspect_getIMPForBlock(id block) {
    struct Block_layout *layout = (__bridge void *)block;
    return layout->invoke;
}

