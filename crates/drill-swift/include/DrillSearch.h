#ifndef DRILL_SEARCH_H
#define DRILL_SEARCH_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DrillSearch DrillSearch;

/* Pointers are borrowed for this call only. Copy path_len bytes for filesystem
 * identity and use name (NUL-terminated UTF-8) for display. rank is 0 for an
 * exact match and 1 for a partial match. Unknown size and modification time
 * are UINT64_MAX and INT64_MIN. Time is Unix seconds rounded down plus
 * modified_nanos in [0, 999999999], or zero nanos for an unknown time. */
typedef void (*DrillHitCallback)(void *ctx, const uint8_t *path, size_t path_len,
                                 const char *name, uint8_t rank, bool is_dir,
                                 uint64_t size, int64_t modified_seconds, uint32_t modified_nanos);

/* Rust path ordering of the original filesystem bytes. Returns -1, 0 or 1.
 * For the Path column, compare parent directories before the full paths.
 * Each nonempty buffer must remain readable throughout this call. */
int32_t drill_compare_paths(const uint8_t *left, size_t left_len, const uint8_t *right,
                            size_t right_len, bool parents_first);

/* Use the handle on one thread. Do not reenter its API during callbacks.
 * Inputs are copied. query is NUL-terminated UTF-8. An explicit filesystem
 * root is root_len original path bytes; a zero length selects Drill's default
 * roots. An empty query lists Apps and returns no Files. */
DrillSearch *drill_search_start(const char *query, bool apps,
                                const uint8_t *root, size_t root_len);

/* Adds session directories to the search above. additional contains consecutive
 * NUL-terminated, nonempty absolute filesystem paths in their original bytes.
 * A zero additional_len means none. All paths are copied before returning. */
DrillSearch *drill_search_start_with_roots(const char *query, bool apps,
                                           const uint8_t *root, size_t root_len,
                                           const uint8_t *additional, size_t additional_len);

/* Borrowed until the next mutable call. NULL means no error. */
const char *drill_search_error(const DrillSearch *search);

/* Delivers up to min(max_hits, 256) hits synchronously without waiting for
 * workers. Returns 1 when all hits have been drained (also on error), else 0.
 * Pass max_hits > 0 and a callback to make progress. */
int32_t drill_search_poll(DrillSearch *search, uint32_t max_hits,
                          void *ctx, DrillHitCallback callback);

/* Resume the same scan with paused=false. Queued hits survive a pause. */
void drill_search_set_paused(DrillSearch *search, bool paused);

/* Cancels startup and traversal. The handle is invalid after this call. */
void drill_search_free(DrillSearch *search);

#ifdef __cplusplus
}
#endif

#endif
