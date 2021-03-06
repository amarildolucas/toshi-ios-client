#import "ShadowsTool.h"
#import "Common.h"

@interface ShadowsTool ()
{
    PhotoProcessPassParameter *_parameter;
}
@end

@implementation ShadowsTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"shadows";
        _type = PhotoToolTypeShader;
        _order = 4;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"ShadowsTool");
}

- (UIImage *)image
{
    return [UIImage imageNamed:@"PhotoEditorShadowsTool"];
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PhotoProcessPassParameter parameterWithName:@"shadows" type:@"lowp float"];
        _parameters = @[ _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = (value.floatValue * 0.55f + 100.0f) / 100.0f;
    [_parameter setFloatValue:parameterValue];
}

@end
