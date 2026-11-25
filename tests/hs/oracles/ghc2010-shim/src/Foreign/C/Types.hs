{-# LANGUAGE PackageImports #-}
-- Foreign.C.Types (T10 chapter 28): base's types, with the shim's numeric and Bits instances (H2010.Instances).
-- The Report exports the types abstractly (T10 28), but GHC marshals a newtype in a foreign declaration only when
-- its constructor is in scope, so the arithmetic types are exported with their constructors: a program naming one
-- (CInt 3) is wrongly accepted.  CFile, CFpos and CJmpBuf stay abstract.
module Foreign.C.Types (
    CChar(..), CSChar(..), CUChar(..), CShort(..), CUShort(..), CInt(..), CUInt(..), CLong(..), CULong(..),
    CPtrdiff(..), CSize(..), CWchar(..), CSigAtomic(..), CLLong(..), CULLong(..), CIntPtr(..), CUIntPtr(..),
    CIntMax(..), CUIntMax(..), CClock(..), CTime(..), CFloat(..), CDouble(..), CFile, CFpos, CJmpBuf
  ) where
import "base" Foreign.C.Types
import H2010.Instances ()
