// YouSoundFix: laat YouTube geluid afspelen als de iPhone op stil staat,
// ook binnen LiveContainer. YouTube kiest daar soms het audiotype
// Ambient/SoloAmbient, dat de stil-schakelaar volgt. Deze tweak zet dat om
// naar Playback (zoals YouTube Music doet), dat de schakelaar negeert.
// Verbergt ook de Downloads-tab in de balk onderin.
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gEnabled = NO;

static NSString *YSFFix(NSString *category, AVAudioSessionCategoryOptions *options) {
    if (!gEnabled || !category) return category;
    if ([category isEqualToString:AVAudioSessionCategoryAmbient]) {
        // Ambient mengde met andere audio; dat gedrag houden we.
        if (options) *options |= AVAudioSessionCategoryOptionMixWithOthers;
        return AVAudioSessionCategoryPlayback;
    }
    if ([category isEqualToString:AVAudioSessionCategorySoloAmbient]) {
        return AVAudioSessionCategoryPlayback;
    }
    return category;
}

static void YSFEnforce(AVAudioSession *s) {
    NSString *cat = s.category;
    AVAudioSessionCategoryOptions opts = s.categoryOptions;
    NSString *fixed = YSFFix(cat, &opts);
    if (fixed != cat) [s setCategory:fixed mode:s.mode options:opts error:nil];
}

%hook AVAudioSession

- (BOOL)setCategory:(NSString *)category error:(NSError **)outError {
    AVAudioSessionCategoryOptions opts = 0;
    NSString *fixed = YSFFix(category, &opts);
    if (fixed != category) return [self setCategory:fixed mode:AVAudioSessionModeDefault options:opts error:outError];
    return %orig;
}

- (BOOL)setCategory:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
    category = YSFFix(category, &options);
    return %orig(category, options, outError);
}

- (BOOL)setCategory:(NSString *)category mode:(NSString *)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
    category = YSFFix(category, &options);
    return %orig(category, mode, options, outError);
}

- (BOOL)setCategory:(NSString *)category mode:(NSString *)mode routeSharingPolicy:(AVAudioSessionRouteSharingPolicy)policy options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
    category = YSFFix(category, &options);
    return %orig(category, mode, policy, options, outError);
}

- (BOOL)setActive:(BOOL)active error:(NSError **)outError {
    if (active && gEnabled) YSFEnforce(self);
    return %orig;
}

- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError {
    if (active && gEnabled) YSFEnforce(self);
    return %orig;
}

%end


// ---- Downloads-tab in de balk onderin verbergen ----
@interface YTIFormattedString : NSObject
- (NSString *)stringWithFormattingRemoved;
@end
@interface YTIPivotBarItemRenderer : NSObject
- (NSString *)pivotIdentifier;
- (YTIFormattedString *)title;
@end
@interface YTIPivotBarSupportedRenderers : NSObject
- (YTIPivotBarItemRenderer *)pivotBarItemRenderer;
@end
@interface YTIPivotBarRenderer : NSObject
- (NSMutableArray *)itemsArray;
@end

static BOOL YSFIsDownloads(id item) {
    if (![item respondsToSelector:@selector(pivotBarItemRenderer)]) return NO;
    YTIPivotBarItemRenderer *r = [item pivotBarItemRenderer];
    NSString *pid = [r respondsToSelector:@selector(pivotIdentifier)] ? [r pivotIdentifier] : nil;
    if ([pid.lowercaseString containsString:@"download"]) return YES;
    YTIFormattedString *t = [r respondsToSelector:@selector(title)] ? [r title] : nil;
    NSString *title = [t respondsToSelector:@selector(stringWithFormattingRemoved)] ? [t stringWithFormattingRemoved] : nil;
    return [title.lowercaseString containsString:@"download"];
}

%group YSFHideDownloads
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    if ([renderer respondsToSelector:@selector(itemsArray)]) {
        NSMutableArray *items = [renderer itemsArray];
        NSIndexSet *weg = [items indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger i, BOOL *stop) {
            return YSFIsDownloads(obj);
        }];
        if (weg.count) [items removeObjectsAtIndexes:weg];
    }
    %orig;
}

// Vangnet: een knop die niet via de renderer komt (bijv. van YouPro zelf).
- (void)layoutSubviews {
    %orig;
    for (UIView *v in ((UIView *)self).subviews) {
        NSString *label = [v.accessibilityLabel lowercaseString];
        NSString *ident = [v.accessibilityIdentifier lowercaseString];
        if ([label containsString:@"download"] || [ident containsString:@"download"]) v.hidden = YES;
    }
}
%end
%end

%ctor {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    // Alleen YouTube zelf, niet YouTube Music (die werkt al goed).
    gEnabled = [bid.lowercaseString containsString:@"youtube"]
            && ![bid.lowercaseString containsString:@"music"];
    if (gEnabled) {
        NSLog(@"[YouSoundFix] actief voor %@", bid);
        YSFEnforce([AVAudioSession sharedInstance]);
        %init;
        if (objc_getClass("YTPivotBarView")) %init(YSFHideDownloads);
    }
}
