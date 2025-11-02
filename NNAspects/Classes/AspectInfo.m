//
//  NNHookInfo.m
//  NNAOPKit
//
//  Created by NeroXie on 2022/10/17.
//

#import "Aspects.h"
#import "AspectContainer.h"

@interface AspectInfo ()

@property (nonatomic, copy) id block;
@property (nonatomic, assign) AspectOptions option;
@property (nonatomic, copy) AspectIdentifier identifier;
@property (nonatomic, assign) BOOL automaticRemoval;

@end

@implementation AspectInfo

+ (instancetype)infoWithOption:(AspectOptions)option identifier:(AspectIdentifier)identifier block:(id)block {
    NSParameterAssert(identifier);
    NSParameterAssert(block);
    
    AspectInfo *info = AspectInfo.new;
    info.option = option;
    info.identifier = identifier;
    info.block = block;
    
    return info;
}

- (void)setOption:(AspectOptions)option {
    _option = option;
    _automaticRemoval = option & AspectOptionAutomaticRemoval;
}

@end
