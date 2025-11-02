//
//  SSColorValueTransformer.m
//  Mudrammer
//
//  Secure value transformer for UIColor in Core Data
//

#import "SSColorValueTransformer.h"

@implementation SSColorValueTransformer

+ (NSString *)transformerName {
    return NSStringFromClass([SSColorValueTransformer class]);
}

+ (Class)transformedValueClass {
    return [UIColor class];
}

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[[UIColor class]];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

@end
