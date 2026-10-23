/* Failure-capable ownership oracle; fixture.h remains unmodified. */
#include <errno.h>
#include "fixture.h"
#if defined(_WIN32)
#include <windows.h>
#endif
RF_EXPORT int rf_checked_free(void *memory, int fail) {
 if (fail) {
  errno=EACCES;
#if defined(_WIN32)
  SetLastError(ERROR_ACCESS_DENIED);
#endif
  return 0;
 }
 rf_free(memory);
 return 1;
}
