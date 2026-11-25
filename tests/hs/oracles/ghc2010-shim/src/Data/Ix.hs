{-# LANGUAGE PackageImports #-}
-- Data.Ix (T10 chapter 19): base's class (derivable, so it must be base's).
module Data.Ix ( Ix(range, index, inRange, rangeSize) ) where
import "base" Data.Ix (Ix(range, index, inRange, rangeSize))
