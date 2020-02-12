#pragma once

#include "WindowContext.hpp"



WindowContext loadUIFromDataFiles(const WindowContext);

/*
    Utility function to do some sanity checks before binding GTK events
*/
void bindEvent(const WindowContext* globalContext, GObject* object, const char* eventName, GCallback callback);