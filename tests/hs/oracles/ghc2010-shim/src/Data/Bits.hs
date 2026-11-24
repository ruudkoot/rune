{-# LANGUAGE PackageImports #-}
-- Data.Bits (T10 chapter 15): the shim's class, `class Num a => Bits a`, with the Report's instances.
module Data.Bits (
    Bits((.&.), (.|.), xor, complement, shift, rotate, bit, setBit, clearBit, complementBit, testBit,
         bitSize, isSigned, shiftL, shiftR, rotateL, rotateR)
  ) where
import H2010.Bits
import H2010.Instances ()
