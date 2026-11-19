#import "DisplayControl.h"
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

// --- Declarações das classes privadas do CoreBrightness ---

@interface CBTrueToneClient : NSObject
- (BOOL)supported;
- (BOOL)available;
- (BOOL)enabled;
- (BOOL)setEnabled:(BOOL)enabled;
@end

typedef struct { int hour; int minute; } CBTime;
typedef struct { CBTime fromTime; CBTime toTime; } CBSchedule;
typedef struct {
    BOOL active;
    BOOL enabled;
    BOOL sunSchedulePermitted;
    int mode;
    CBSchedule schedule;
    unsigned long long disableFlags;
    BOOL available;
} CBBlueLightStatus;

@interface CBBlueLightClient : NSObject
+ (BOOL)supportsBlueLightReduction;
- (BOOL)getBlueLightStatus:(CBBlueLightStatus *)status;
- (BOOL)setEnabled:(BOOL)enabled;
@end

typedef int (*DSGetBrightnessFn)(CGDirectDisplayID, float *);
typedef int (*DSSetBrightnessFn)(CGDirectDisplayID, float);

static void LoadCoreBrightness(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CoreBrightness.framework"] load];
    });
}

static void *DisplayServicesHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW);
    });
    return handle;
}

static CGDirectDisplayID BuiltInDisplay(void) {
    CGDirectDisplayID ids[16];
    uint32_t count = 0;
    if (CGGetOnlineDisplayList(16, ids, &count) != kCGErrorSuccess) return kCGNullDirectDisplay;
    for (uint32_t i = 0; i < count; i++) {
        if (CGDisplayIsBuiltin(ids[i])) return ids[i];
    }
    return kCGNullDirectDisplay;
}

@implementation DisplayControl

#pragma mark True Tone

+ (CBTrueToneClient *)trueToneClient {
    static CBTrueToneClient *client = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        LoadCoreBrightness();
        Class cls = NSClassFromString(@"CBTrueToneClient");
        if (cls) client = [[cls alloc] init];
    });
    return client;
}

+ (BOOL)trueToneSupported {
    CBTrueToneClient *c = [self trueToneClient];
    return c && [c supported] && [c available];
}

+ (BOOL)trueToneEnabled {
    CBTrueToneClient *c = [self trueToneClient];
    return c ? [c enabled] : NO;
}

+ (BOOL)setTrueToneEnabled:(BOOL)enabled {
    CBTrueToneClient *c = [self trueToneClient];
    if (!c) return NO;
    return [c setEnabled:enabled];
}

#pragma mark Night Shift

+ (CBBlueLightClient *)blueLightClient {
    static CBBlueLightClient *client = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        LoadCoreBrightness();
        Class cls = NSClassFromString(@"CBBlueLightClient");
        if (cls) client = [[cls alloc] init];
    });
    return client;
}

+ (BOOL)nightShiftSupported {
    Class cls = NSClassFromString(@"CBBlueLightClient");
    if (!cls) { LoadCoreBrightness(); cls = NSClassFromString(@"CBBlueLightClient"); }
    return cls && [cls supportsBlueLightReduction];
}

+ (BOOL)nightShiftEnabled {
    CBBlueLightClient *c = [self blueLightClient];
    if (!c) return NO;
    CBBlueLightStatus status;
    memset(&status, 0, sizeof(status));
    if (![c getBlueLightStatus:&status]) return NO;
    return status.enabled;
}

+ (BOOL)setNightShiftEnabled:(BOOL)enabled {
    CBBlueLightClient *c = [self blueLightClient];
    if (!c) return NO;
    return [c setEnabled:enabled];
}

#pragma mark Brilho

+ (float)builtInBrightness {
    void *h = DisplayServicesHandle();
    CGDirectDisplayID d = BuiltInDisplay();
    if (!h || d == kCGNullDirectDisplay) return -1;
    DSGetBrightnessFn fn = (DSGetBrightnessFn)dlsym(h, "DisplayServicesGetBrightness");
    if (!fn) return -1;
    float v = -1;
    if (fn(d, &v) != 0) return -1;
    return v;
}

+ (BOOL)setBuiltInBrightness:(float)value {
    void *h = DisplayServicesHandle();
    CGDirectDisplayID d = BuiltInDisplay();
    if (!h || d == kCGNullDirectDisplay) return NO;
    DSSetBrightnessFn fn = (DSSetBrightnessFn)dlsym(h, "DisplayServicesSetBrightness");
    if (!fn) return NO;
    float v = fmaxf(0.0f, fminf(1.0f, value));
    return fn(d, v) == 0;
}

@end
