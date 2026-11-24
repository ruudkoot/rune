{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- H2010.Bits: Data.Bits's class as the Haskell 2010 Report has it (T10 chapter 15): `class Num a => Bits a`, the
-- seventeen methods of the export list, the minimal complete definition of T10 15.1.  Default methods are base's of
-- 2010 (the Report gives none in code).  Instances are H2010.Instances's.
module H2010.Bits (
    Bits((.&.), (.|.), xor, complement, shift, rotate, bit, setBit, clearBit, complementBit, testBit,
         bitSize, isSigned, shiftL, shiftR, rotateL, rotateR)
  ) where

import "base" Prelude (Eq(..), Ord(..), Bool(..), Int, otherwise)
import H2010.Classes

infixl 8 `shift`, `rotate`, `shiftL`, `shiftR`, `rotateL`, `rotateR`
infixl 7 .&.
infixl 6 `xor`
infixl 5 .|.

class Num a => Bits a where
    (.&.), (.|.), xor :: a -> a -> a
    complement        :: a -> a
    shift             :: a -> Int -> a
    rotate            :: a -> Int -> a
    bit               :: Int -> a
    setBit, clearBit, complementBit :: a -> Int -> a
    testBit           :: a -> Int -> Bool
    bitSize           :: a -> Int
    isSigned          :: a -> Bool
    shiftL, shiftR    :: a -> Int -> a
    rotateL, rotateR  :: a -> Int -> a

    x `shift`   i | i<0  = x `shiftR` (-i)
                  | i>0  = x `shiftL` i
                  | otherwise = x
    x `rotate`  i | i<0  = x `rotateR` (-i)
                  | i>0  = x `rotateL` i
                  | otherwise = x
    bit i               = 1 `shiftL` i
    x `setBit` i        = x .|. bit i
    x `clearBit` i      = x .&. complement (bit i)
    x `complementBit` i = x `xor` bit i
    x `testBit` i       = (x .&. bit i) /= 0
    x `shiftL`  i = x `shift`  i
    x `shiftR`  i = x `shift`  (-i)
    x `rotateL` i = x `rotate` i
    x `rotateR` i = x `rotate` (-i)
