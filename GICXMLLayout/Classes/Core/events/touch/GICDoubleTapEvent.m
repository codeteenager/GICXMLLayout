//
//  GICDoubleTapEvent.m
//  GICXMLLayout
//
//  Created by 龚海伟 on 2018/8/31.
//

#import "GICDoubleTapEvent.h"

@implementation GICDoubleTapEvent
+(NSString *)eventName{
    return @"event-double-tap";
}
-(GICCustomTouchEventMethodOverride)overrideType{
    return GICCustomTouchEventMethodOverrideTouchesEnded;
}

-(void)attachTo:(ASDisplayNode *)target{
    [super attachTo:target];
    // 为了解决RAC 的线程安全问题，只能强制调度到ElementQueue 线程上执行。以免在并发的时候会出现crash的问题。
    @weakify(self)
    [GICDoubleTapEvent performThreadSafe:^{
        [[target rac_signalForSelector:@selector(touchesEnded:withEvent:)] subscribeNext:^(RACTuple * _Nullable x) {
            NSSet *touches = x[0];
            UITouch *touch = [touches anyObject];
            @strongify(self)
            if (touch.tapCount == 2) {
                if(self->isRejectEnum){
                    [(_ASDisplayView *)((ASDisplayNode *)self.target).view __forwardTouchesEnded:x[0] withEvent:x[1]];
                }
                [self.eventSubject sendNext:touch];
            }
        }];
    }];
}
@end
