#ifndef DRILL_ICON_H
#define DRILL_ICON_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum { DRILL_ICON_SIDE = 32, DRILL_ICON_RGBA_BYTES = 4096 };

/* Synchronous. Call on a bounded background worker for .exe and .AppImage
 * candidates. path is the original filesystem path (1 to 4096 bytes, no NUL).
 * rgba_len must be DRILL_ICON_RGBA_BYTES. A true return fills rgba with
 * 32 x 32 top-to-bottom, straight-alpha RGBA pixels; false leaves it untouched.
 * Both pointers are borrowed only for this call and must not overlap. */
bool drill_decode_icon(const uint8_t *path, size_t path_len,
                       uint8_t *rgba, size_t rgba_len);

#ifdef __cplusplus
}
#endif

#endif
