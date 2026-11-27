#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef void (*DrillClipboardTextSink)(void *context, const uint8_t *bytes, size_t length);

void *drill_macos_clipboard_open(void);
void drill_macos_clipboard_close(void *handle);
void drill_macos_clipboard_read_text(void *handle, void *context, DrillClipboardTextSink sink);
bool drill_macos_clipboard_write_text(void *handle, const uint8_t *bytes, size_t length);
bool drill_macos_clipboard_write_rgba(void *handle, const uint8_t *rgba, size_t length, size_t width, size_t height);
