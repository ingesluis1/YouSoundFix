// YouSoundFix: laat YouTube geluid afspelen als de iPhone op stil staat,
// ook binnen LiveContainer. YouTube kiest daar soms het audiotype
// Ambient/SoloAmbient, dat de stil-schakelaar volgt. Deze tweak zet dat om
// naar Playback (zoals YouTube Music doet), dat de schakelaar negeert.
#import <AVFoundation/AVFoundation.h>

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

%ctor {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    // Alleen YouTube zelf, niet YouTube Music (die werkt al goed).
    gEnabled = [bid.lowercaseString containsString:@"youtube"]
            && ![bid.lowercaseString containsString:@"music"];
    if (gEnabled) {
        NSLog(@"[YouSoundFix] actief voor %@", bid);
        YSFEnforce([AVAudioSession sharedInstance]);
    }
}
