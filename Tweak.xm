#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSTimeInterval WXLastHapticTime = 0;

static BOOL WXIsWeChatTabText(NSString *text) {
    if (text.length == 0) return NO;

    return [text isEqualToString:@"微信"] ||
           [text hasPrefix:@"微信("] ||
           [text isEqualToString:@"通讯录"] ||
           [text isEqualToString:@"发现"] ||
           [text isEqualToString:@"我"];
}

static NSString *WXTextFromView(UIView *view) {
    if (!view) return nil;

    if ([view isKindOfClass:UILabel.class]) {
        return ((UILabel *)view).text;
    }

    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        return button.currentTitle ?: button.titleLabel.text;
    }

    return nil;
}

static BOOL WXViewContainsWeChatTabText(UIView *view) {
    if (!view) return NO;

    NSString *text = WXTextFromView(view);
    if (WXIsWeChatTabText(text)) {
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if (WXViewContainsWeChatTabText(subview)) {
            return YES;
        }
    }

    return NO;
}

static void WXDoLightHaptic(void) {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;

    // 防止一次点击触发多次震动
    if (now - WXLastHapticTime < 0.25) {
        return;
    }

    WXLastHapticTime = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator =
                [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

            [generator prepare];
            [generator impactOccurred];
        }
    });
}

%hook UITabBarButton

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (WXViewContainsWeChatTabText((UIView *)self)) {
        WXDoLightHaptic();
    }

    %orig;
}

%end

%ctor {
    NSLog(@"[WXTabHaptic] clean first-style haptic loaded");
}
