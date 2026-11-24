{-# LANGUAGE PackageImports #-}
-- Foreign.Marshal (T10 chapter 30).
module Foreign.Marshal (
    module Foreign.Marshal.Alloc, module Foreign.Marshal.Array,
    module Foreign.Marshal.Error, module Foreign.Marshal.Utils,
    unsafeLocalState
  ) where
import Foreign.Marshal.Alloc
import Foreign.Marshal.Array
import Foreign.Marshal.Error
import Foreign.Marshal.Utils
import "base" Foreign.Marshal.Unsafe (unsafeLocalState)
