// PrivateAPI.h
// Declarations for the undocumented system calls OpenTaskbar links against.
// Exists because the SDK ships link stubs for these symbols but no headers.
// Defines: KeyboardBrightnessClient, DisplayServices, CoreDock, AX and SecTranslocate calls
// Notes: docs/notes/app/Sources/PrivateAPI/include/PrivateAPI.h.md
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreGraphics/CoreGraphics.h>

// DisplayServices.framework: the built-in panel's brightness, 0 to 1.
extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
extern int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);
extern bool DisplayServicesCanChangeBrightness(CGDirectDisplayID display);

// HIServices: asks the Dock to run one of its own actions by name.
extern void CoreDockSendNotification(CFStringRef notification, int unused);

// HIServices: the window server id behind an accessibility window element.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *identifier);

// Security.framework: where a translocated bundle was opened from.
extern CFURLRef SecTranslocateCreateOriginalPathForURL(CFURLRef translocatedPath, CFErrorRef *error);
extern Boolean SecTranslocateIsTranslocatedURL(CFURLRef path, bool *isTranslocated, CFErrorRef *error);

// CoreBrightness.framework: the keyboard backlight level, 0 to 1.
@interface KeyboardBrightnessClient : NSObject
- (NSArray *)copyKeyboardBacklightIDs;
- (float)brightnessForKeyboard:(unsigned long long)keyboardID;
- (BOOL)setBrightness:(float)brightness forKeyboard:(unsigned long long)keyboardID;
- (BOOL)isKeyboardBuiltIn:(unsigned long long)keyboardID;
@end
