{-# LANGUAGE PackageImports #-}
-- Foreign.Marshal.Alloc (T10 chapter 31): base's.
module Foreign.Marshal.Alloc (
    alloca, allocaBytes, malloc, mallocBytes, realloc, reallocBytes, free, finalizerFree
  ) where
import "base" Foreign.Marshal.Alloc
