#ifndef DRILL_DESKTOP_H
#define DRILL_DESKTOP_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef _WIN32
typedef uint16_t DrillPathChar;
#else
typedef char DrillPathChar;
#endif

/* All calls are serialized on the UI thread. Borrowed text and paths must
 * be copied before a model mutation or a nested menu/dialog event loop. */
typedef struct DrillModel DrillModel;
typedef struct {
    uint64_t revision, icon_revision;
    size_t count;
    int64_t selected_index; /* -1 means no selection */
    const char *status;
    bool can_stop, can_continue;
    bool poll_again; /* A full batch was delivered. Schedule another UI turn. */
} DrillState;
typedef struct {
    const char *cells[4]; /* UTF-8 Name, parent Path, Size, Date */
    const DrillPathChar *path; /* NUL-terminated original filename encoding */
    bool directory, registered_app;
    const char *desktop_id; /* registered GIO desktop ID, otherwise NULL */
} DrillRow;
void drill_query(DrillModel *, const char *utf8, bool apps);
DrillState drill_tick(DrillModel *);
void drill_stop(DrillModel *);
void drill_continue(DrillModel *);
void drill_sort(DrillModel *, unsigned column);
void drill_select(DrillModel *, uint64_t id); /* 0 clears selection */
uint64_t drill_row_id(const DrillModel *, size_t index); /* 0 if absent */
bool drill_row(const DrillModel *, uint64_t id, DrillRow *out);
/* 32x32 straight RGBA. 1 ready, 0 pending, -1 use platform fallback. */
int drill_embedded_icon(DrillModel *, uint64_t id, bool exe, bool appimage, uint8_t rgba[4096]);
/* Implemented by the target SDK adapter. Model remains owned by Rust. */
int drill_native_run(DrillModel *);
#endif
