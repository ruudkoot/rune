{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- Foreign.Marshal.Utils (T10 chapter 34): base's, except fromBool and toBool (their types name Num): base's code over
-- the shim's classes.
module Foreign.Marshal.Utils (
    with, new, fromBool, toBool, maybeNew, maybeWith, maybePeek, withMany, copyBytes, moveBytes
  ) where
import "base" Prelude (Eq(..), Bool(..), not)
import "base" Foreign.Marshal.Utils (with, new, maybeNew, maybeWith, maybePeek, withMany, copyBytes, moveBytes)
import H2010.Classes

fromBool :: Num a => Bool -> a
fromBool False = 0
fromBool True  = 1
toBool :: (Eq a, Num a) => a -> Bool
toBool = (/= 0)
