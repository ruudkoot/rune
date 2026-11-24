{-# LANGUAGE PackageImports #-}
-- Foreign.ForeignPtr (T10 chapter 29): base's.
module Foreign.ForeignPtr (
    ForeignPtr, FinalizerPtr, FinalizerEnvPtr, newForeignPtr,
    newForeignPtr_, addForeignPtrFinalizer, newForeignPtrEnv,
    addForeignPtrFinalizerEnv, withForeignPtr, finalizeForeignPtr,
    unsafeForeignPtrToPtr, touchForeignPtr, castForeignPtr,
    mallocForeignPtr, mallocForeignPtrBytes, mallocForeignPtrArray,
    mallocForeignPtrArray0
  ) where
import "base" Foreign.ForeignPtr
import "base" Foreign.ForeignPtr.Unsafe (unsafeForeignPtrToPtr)
