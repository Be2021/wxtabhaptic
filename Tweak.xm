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
    return YES;
}

static BOOL WXUseAudioFallback(void) {
    return YES;
}

static SystemSoundID WXAudioFallbackSoundID(void) {
    // 1519 轻中等，1520 中偏强，1521 较强
    return 1519;
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
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            }

            if (!WXSelectionGenerator) {
                WXSelectionGenerator = [[UISelectionFeedbackGenerator alloc] init];
            }

            [WXImpactGenerator prepare];
            [WXSelectionGenerator prepare];
        }
    });
}

static void WXDoMediumHaptic(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            if (!WXImpactGenerator) {
                WXImpactGenerator =
                    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            }

            if (!WXSelectionGenerator) {
                WXSelectionGenerator = [[UISelectionFeedbackGenerator alloc] init];
            }

            [WXImpactGenerator prepare];
            [WXImpactGenerator impactOccurred];

            // 轻微补一下，不会太重
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.018 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [WXSelectionGenerator prepare];
                [WXSelectionGenerator selectionChanged];
            });
        }

        if (WXUseAudioFallback()) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.012 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                AudioServicesPlaySystemSound(WXAudioFallbackSoundID());
            });
        }
    });
}

static void WXDoTabHaptic(NSString *tabText) {
    if (!WXTabHapticEnabled()) return;
    if (tabText.length == 0) return;

    NSTimeInterval now = NSDate.date.timeIntervalSince1970;

    if (now - WXLastHapticTime < 0.16) {
        return;
    }

    WXLastTabText = tabText;
    WXLastHapticTime = now;

    WXPrepareHaptic();
    WXDoMediumHaptic();
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

    NSLog(@"[WXTabHaptic] medium haptic loaded");
}
