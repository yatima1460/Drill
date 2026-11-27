#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#include <stdbool.h>
#include <stdint.h>

// This adapter supplies the drawable for eframe's existing OpenGL painter.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void *drill_gl_context(uint8_t depth, uint8_t stencil, uint8_t samples,
                       bool accelerated, bool transparent) {
    if (!NSThread.isMainThread) {
        return NULL;
    }

    NSOpenGLPixelFormatAttribute attributes[23] = {
        NSOpenGLPFAMinimumPolicy, NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFAColorSize, 32, NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, depth, NSOpenGLPFAStencilSize, stencil,
        NSOpenGLPFADoubleBuffer,
    };
    size_t count = 11;
    if (samples != 0) {
        attributes[count++] = NSOpenGLPFAMultisample;
        attributes[count++] = NSOpenGLPFASampleBuffers;
        attributes[count++] = 1;
        attributes[count++] = NSOpenGLPFASamples;
        attributes[count++] = samples;
    }
    if (accelerated) {
        attributes[count++] = NSOpenGLPFAAccelerated;
    }
    attributes[count++] = NSOpenGLPFAOpenGLProfile;
    const NSOpenGLPixelFormatAttribute profiles[] = {
        NSOpenGLProfileVersion4_1Core, NSOpenGLProfileVersion3_2Core, NSOpenGLProfileVersionLegacy,
    };

    @autoreleasepool {
        NSOpenGLPixelFormat *format = nil;
        for (size_t i = 0; i < sizeof profiles / sizeof profiles[0]; i++) {
            attributes[count] = profiles[i];
            format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
            if (format != nil) {
                break;
            }
        }
        if (format == nil) {
            return NULL;
        }

        NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
        if (transparent && context != nil) {
            GLint opacity = 0;
            if (CGLSetParameter(context.CGLContextObj, kCGLCPSurfaceOpacity, &opacity) != kCGLNoError) {
                return NULL;
            }
        }
        return (__bridge_retained void *)context;
    }
}

void drill_gl_free_context(void *raw_context) {
    NSOpenGLContext *context = (__bridge_transfer NSOpenGLContext *)raw_context;
    if (NSOpenGLContext.currentContext == context) {
        [NSOpenGLContext clearCurrentContext];
    }
    [context clearDrawable];
}

void *drill_gl_surface(void *raw_view) {
    NSView *view = (__bridge NSView *)raw_view;
    if (view.window == nil) {
        return NULL;
    }

    view.wantsBestResolutionOpenGLSurface = YES;
    // AppKit can enable layer backing after attachment, invalidating the drawable.
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_12) {
        view.wantsLayer = YES;
    }
    return (__bridge_retained void *)view;
}

void drill_gl_free_surface(void *raw_context, void *raw_view) {
    NSOpenGLContext *context = (__bridge NSOpenGLContext *)raw_context;
    NSView *view = (__bridge_transfer NSView *)raw_view;
    if (context.view == view) {
        [context clearDrawable];
        if (NSOpenGLContext.currentContext == context) {
            [NSOpenGLContext clearCurrentContext];
        }
    }
}

bool drill_gl_activate(void *raw_context, void *raw_view) {
    NSOpenGLContext *context = (__bridge NSOpenGLContext *)raw_context;
    NSView *view = (__bridge NSView *)raw_view;
    if (context.view != view || NSOpenGLContext.currentContext != context) {
        [context makeCurrentContext];
        context.view = view;
        [context update];
    }
    return NSOpenGLContext.currentContext == context && context.view == view;
}

void drill_gl_update(void *raw_context) {
    NSOpenGLContext *context = (__bridge NSOpenGLContext *)raw_context;
    [context update];
}

bool drill_gl_swap(void *raw_context, void *raw_view) {
    NSOpenGLContext *context = (__bridge NSOpenGLContext *)raw_context;
    NSView *view = (__bridge NSView *)raw_view;
    if (NSOpenGLContext.currentContext != context || context.view != view) {
        return false;
    }
    [context flushBuffer];
    return true;
}

void drill_gl_vsync(void *raw_context, bool vsync) {
    NSOpenGLContext *context = (__bridge NSOpenGLContext *)raw_context;
    GLint interval = vsync;
    [context setValues:&interval forParameter:NSOpenGLCPSwapInterval];
}

void *drill_gl_symbol(const char *name) {
    CFBundleRef framework = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    if (framework == NULL) {
        return NULL;
    }
    CFStringRef symbol = CFStringCreateWithCString(NULL, name, kCFStringEncodingASCII);
    if (symbol == NULL) {
        return NULL;
    }
    void *address = CFBundleGetFunctionPointerForName(framework, symbol);
    CFRelease(symbol);
    return address;
}

#pragma clang diagnostic pop
