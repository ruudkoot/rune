{-# LANGUAGE PackageImports #-}
-- Data.Int (T10 chapter 18): base's types, with the shim's numeric instances (H2010.Instances).
module Data.Int ( Int, Int8, Int16, Int32, Int64 ) where
import "base" Data.Int ( Int, Int8, Int16, Int32, Int64 )
import H2010.Instances ()
