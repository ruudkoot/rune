{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- Foreign.Marshal.Error (T10 chapter 33): base's throwIf, throwIf_ and throwIfNull; throwIfNeg, throwIfNeg_ (their
-- types name Num) and void (gone from base) are base's code of 2010 over the shim's classes.
module Foreign.Marshal.Error ( throwIf, throwIf_, throwIfNeg, throwIfNeg_, throwIfNull, void ) where
import "base" Prelude (Ord(..), String, IO)
import "base" Foreign.Marshal.Error (throwIf, throwIf_, throwIfNull)
import H2010.Classes

throwIfNeg :: (Ord a, Num a) => (a -> String) -> IO a -> IO a
throwIfNeg = throwIf (< 0)
throwIfNeg_ :: (Ord a, Num a) => (a -> String) -> IO a -> IO ()
throwIfNeg_ = throwIf_ (< 0)
void :: IO a -> IO ()
void act = act >> return ()
