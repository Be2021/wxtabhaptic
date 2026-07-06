#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSTimeInterval WXLastHapticTime = 0;
static NSString *WXLastTabText = nil;

static UIImpactFeedbackGenerator *WXImpactGenerator = nil;

static BOOL WXTabHapticEnabled(void) {
    return YES;
}

static BOOL WXAllowRepeatCurrentTabHaptic(void) {
    // YES：重复点击当前 Tab 也震动
    // NO：只有切换不同 Tab 才震动
    return YES;
}

static NSString *WXNormalizeTabText(NSString *text) {
    if (text.length == 0) return nil;

    if ([text hasPrefix:@"微信"]) return @"微信";
    if ([text isEqualToString:@"通讯录"]) return @"通讯录";
    if ([text isEqualToString:@"发现"]) return @"发现";
    if ([text isEqualToString:@"我"]) return @"我";

    return nil;
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

static NSString *WXFindTabTextInView(UIView *view) {
    if (!view) return nil;

    NSString *text = WXNormalizeTabText(WXTextFromView(view));
    if (text.length > 0) return text;

    for (UIView *subview in view.subviews) {
        NSString *found = WXFindTabTextInView(subview);
        if (found.length > 0) return found;
    }

    return nil;
}

static void WXPrepareHaptic(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            if (!WXImpactGenerator) {
                WXImpactGenerator =
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            }

            [WXImpactGenerator prepare];
        }
    });
}

static void WXDoLightHaptic(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            if (!WXImpactGenerator) {
                WXImpactGenerator =
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            }

            [WXImpactGenerator prepare];
            [WXImpactGenerator impactOccurred];
        }
    });
}

static void WXDoTabHaptic(NSString *tabText) {
    if (!WXTabHapticEnabled()) return;
    if (tabText.length == 0) return;

    NSTimeInterval now = NSDate.date.timeIntervalSince1970;

    // 防止 UITabBarButton 和 MMTabBarItemView 双重触发
    if (now - WXLastHapticTime < 0.28) {
        return;
    }

    if (!WXAllowRepeatCurrentTabHaptic() &&
        WXLastTabText &&
        [WXLastTabText isEqualToString:tabText]) {
        return;
    }

    WXLastTabText = tabText;
    WXLastHapticTime = now;

    WXPrepareHaptic();
    WXDoLightHaptic();
}

%hook UITabBarButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSString *tabText = WXFindTabTextInView((UIView *)self);

    if (tabText.length > 0) {
        WXDoTabHaptic(tabText);
    }

    %orig;
}

%end

%hook MMTabBarItemView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSString *tabText = WXFindTabTextInView((UIView *)self);

    if (tabText.length > 0) {
        WXDoTabHaptic(tabText);
    }

    %orig;
}

%end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        WXPrepareHaptic();
    });

    NSLog(@"[WXTabHaptic] light clean haptic loaded");
}
