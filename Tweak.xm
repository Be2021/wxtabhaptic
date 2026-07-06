#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

static NSTimeInterval WXLastHapticTime = 0;
static NSString *WXLastTabText = nil;

static UIImpactFeedbackGenerator *WXImpactGenerator = nil;
static UISelectionFeedbackGenerator *WXSelectionGenerator = nil;

static BOOL WXTabHapticEnabled(void) {
    return YES;
}

static BOOL WXAllowRepeatCurrentTabHaptic(void) {
    // YES：重复点击当前 Tab 也震动
    // NO：只有切换不同 Tab 才震动
    return YES;
}

static BOOL WXUseAudioFallback(void) {
    // YES：UIKit 触感 + AudioServices 兜底，巨魔和无根都更明显
    return YES;
}

static SystemSoundID WXAudioFallbackSoundID(void) {
    // 1519：轻触
    // 1520：中等
    // 1521：稍强
    // kSystemSoundID_Vibrate：最强但偏长
    return 1520;
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
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            }

            if (!WXSelectionGenerator) {
                WXSelectionGenerator = [[UISelectionFeedbackGenerator alloc] init];
            }

            [WXImpactGenerator prepare];
            [WXSelectionGenerator prepare];
        }
    });
}

static void WXDoCombinedHaptic(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            if (!WXImpactGenerator) {
                WXImpactGenerator =
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            }

            if (!WXSelectionGenerator) {
                WXSelectionGenerator = [[UISelectionFeedbackGenerator alloc] init];
            }

            [WXImpactGenerator prepare];
            [WXImpactGenerator impactOccurred];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.025 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [WXSelectionGenerator prepare];
                [WXSelectionGenerator selectionChanged];
            });
        }

        if (WXUseAudioFallback()) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.015 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                AudioServicesPlaySystemSound(WXAudioFallbackSoundID());
            });
        }
    });
}

static void WXDoTabHaptic(NSString *tabText) {
    if (!WXTabHapticEnabled()) return;
    if (tabText.length == 0) return;

    NSTimeInterval now = NSDate.date.timeIntervalSince1970;

    // 避免 UITabBarButton 和 MMTabBarItemView 同时触发导致连续两下
    if (now - WXLastHapticTime < 0.14) {
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
    WXDoCombinedHaptic();
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

    NSLog(@"[WXTabHaptic] universal haptic loaded");
}
