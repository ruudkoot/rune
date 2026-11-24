{-# LANGUAGE PackageImports #-}
-- Data.Array (T10 chapter 14): base's array package; Functor (Array i) is the shim's (H2010.Classes).
module Data.Array (
    module Data.Ix, Array, array, listArray, accumArray, (!), bounds, indices, elems, assocs, (//), accum, ixmap
  ) where
import "array" Data.Array (Array, array, listArray, accumArray, (!), bounds, indices, elems, assocs, (//), accum, ixmap)
import Data.Ix
import H2010.Classes ()
