{-# LANGUAGE PackageImports #-}
-- Data.Word (T10 chapter 23): base's types, with the shim's numeric instances (H2010.Instances).
module Data.Word ( Word, Word8, Word16, Word32, Word64 ) where
import "base" Data.Word ( Word, Word8, Word16, Word32, Word64 )
import H2010.Instances ()
