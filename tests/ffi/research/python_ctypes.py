"""Independent ctypes comparison, not the Rune test coordinator."""
import ctypes as c
import sys
library = c.CDLL(sys.argv[1], use_errno=True)
class Pair(c.Structure):
    _fields_ = [('integer', c.c_int32), ('fraction', c.c_double)]
library.rf_i64.argtypes = [c.c_int64]
library.rf_i64.restype = c.c_int64
assert library.rf_i64(-(1 << 63)) == -(1 << 63)
library.rf_make_pair.argtypes = [c.c_int32, c.c_double]
library.rf_make_pair.restype = Pair
pair = library.rf_make_pair(39, 3.5)
assert (pair.integer, pair.fraction) == (39, 3.5)
library.rf_copy.argtypes = [c.c_char_p]
library.rf_copy.restype = c.c_void_p
library.rf_free.argtypes = [c.c_void_p]
library.rf_free.restype = None
pointer = library.rf_copy(b'owned')
assert c.string_at(pointer) == b'owned'
library.rf_free(pointer)
assert library.rf_allocations() == 0
Callback = c.CFUNCTYPE(c.c_int, c.c_void_p, c.c_int)
callback = Callback(lambda context, value: value + 20)
library.rf_set_callback.argtypes = [Callback, c.c_void_p]
library.rf_set_callback.restype = None
library.rf_set_callback(callback, None)
assert library.rf_invoke(22) == 42
library.rf_set_callback(Callback(), None)
assert library.rf_invoke(22) == -1
print('PASS ffi/research/ctypes: scalar, struct, owned string, retained callback')
