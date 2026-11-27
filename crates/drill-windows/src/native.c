#if defined(DRILL_DESKTOP)
#define UNICODE
#define _UNICODE
#ifndef COBJMACROS
#define COBJMACROS
#endif
#endif

#if defined(DRILL_SHELL_ICONS)
#include "file_icon.c"
#endif

#if defined(DRILL_CLIPBOARD)
#include "clipboard.c"
#endif

#if defined(DRILL_MENU)
#include "menu.c"
#endif

#if defined(DRILL_DESKTOP)
#include "window_actions.h"
#include "window_icons.c"
#include "window_panels.c"
#include "window_actions.c"
#include "window.c"
#endif
