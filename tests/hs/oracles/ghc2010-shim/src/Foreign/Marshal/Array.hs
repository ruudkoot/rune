{-# LANGUAGE PackageImports #-}
-- Foreign.Marshal.Array (T10 chapter 32): base's.
module Foreign.Marshal.Array (
    mallocArray, mallocArray0, allocaArray, allocaArray0, reallocArray,
    reallocArray0, peekArray, peekArray0, pokeArray, pokeArray0, newArray,
    newArray0, withArray, withArray0, withArrayLen, withArrayLen0,
    copyArray, moveArray, lengthArray0, advancePtr
  ) where
import "base" Foreign.Marshal.Array
