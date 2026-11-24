{-# LANGUAGE PackageImports #-}
-- Foreign.Ptr (T10 chapter 35): base's; IntPtr and WordPtr have the shim's numeric instances, and are exported with
-- their constructors so that GHC marshals them in foreign declarations (the Report exports them abstractly).
module Foreign.Ptr (
    Ptr, nullPtr, castPtr, plusPtr, alignPtr, minusPtr, FunPtr,
    nullFunPtr, castFunPtr, castFunPtrToPtr, castPtrToFunPtr,
    freeHaskellFunPtr, IntPtr(..), ptrToIntPtr, intPtrToPtr, WordPtr(..),
    ptrToWordPtr, wordPtrToPtr
  ) where
import "base" Foreign.Ptr ( Ptr, nullPtr, castPtr, plusPtr, alignPtr, minusPtr, FunPtr,
    nullFunPtr, castFunPtr, castFunPtrToPtr, castPtrToFunPtr, freeHaskellFunPtr, IntPtr(..), ptrToIntPtr, intPtrToPtr,
    WordPtr(..), ptrToWordPtr, wordPtrToPtr )
import H2010.Instances ()
