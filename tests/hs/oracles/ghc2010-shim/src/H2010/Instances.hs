{-# LANGUAGE RebindableSyntax, PackageImports #-}
-- The 2010 shim's classes for base's other numeric types, delegating to base: Num and Real for every type of T10
-- chapters 18, 23, 28 and 35, Integral and Bits for the integral ones, Fractional, Floating, RealFrac and RealFloat
-- for CFloat and CDouble, Bits for Int and Integer.  Written by E8's generator (the haskell2010 drafts'
-- oracles/ghc2010/gen.py, which does not land) and kept by hand since.
module H2010.Instances () where
import "base" Prelude (Int, Integer)
import qualified "base" Prelude as P
import qualified "base" Data.Bits as B
import "base" Data.Int (Int8, Int16, Int32, Int64)
import "base" Data.Word (Word, Word8, Word16, Word32, Word64)
import "base" Foreign.Ptr (IntPtr, WordPtr)
import "base" Foreign.C.Types
import H2010.Classes
import H2010.Bits

instance Num Int8 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Int8 where { toRational = P.toRational }
instance Integral Int8 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Int8 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Int16 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Int16 where { toRational = P.toRational }
instance Integral Int16 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Int16 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Int32 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Int32 where { toRational = P.toRational }
instance Integral Int32 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Int32 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Int64 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Int64 where { toRational = P.toRational }
instance Integral Int64 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Int64 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Word where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Word where { toRational = P.toRational }
instance Integral Word where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Word where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Word8 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Word8 where { toRational = P.toRational }
instance Integral Word8 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Word8 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Word16 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Word16 where { toRational = P.toRational }
instance Integral Word16 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Word16 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Word32 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Word32 where { toRational = P.toRational }
instance Integral Word32 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Word32 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num Word64 where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real Word64 where { toRational = P.toRational }
instance Integral Word64 where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits Word64 where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num IntPtr where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real IntPtr where { toRational = P.toRational }
instance Integral IntPtr where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits IntPtr where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num WordPtr where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real WordPtr where { toRational = P.toRational }
instance Integral WordPtr where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits WordPtr where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CChar where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CChar where { toRational = P.toRational }
instance Integral CChar where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CChar where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CSChar where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CSChar where { toRational = P.toRational }
instance Integral CSChar where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CSChar where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CUChar where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CUChar where { toRational = P.toRational }
instance Integral CUChar where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CUChar where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CShort where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CShort where { toRational = P.toRational }
instance Integral CShort where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CShort where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CUShort where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CUShort where { toRational = P.toRational }
instance Integral CUShort where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CUShort where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CInt where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CInt where { toRational = P.toRational }
instance Integral CInt where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CInt where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CUInt where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CUInt where { toRational = P.toRational }
instance Integral CUInt where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CUInt where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CLong where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CLong where { toRational = P.toRational }
instance Integral CLong where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CLong where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CULong where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CULong where { toRational = P.toRational }
instance Integral CULong where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CULong where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CPtrdiff where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CPtrdiff where { toRational = P.toRational }
instance Integral CPtrdiff where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CPtrdiff where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CSize where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CSize where { toRational = P.toRational }
instance Integral CSize where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CSize where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CWchar where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CWchar where { toRational = P.toRational }
instance Integral CWchar where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CWchar where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CSigAtomic where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CSigAtomic where { toRational = P.toRational }
instance Integral CSigAtomic where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CSigAtomic where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CLLong where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CLLong where { toRational = P.toRational }
instance Integral CLLong where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CLLong where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CULLong where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CULLong where { toRational = P.toRational }
instance Integral CULLong where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CULLong where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CIntPtr where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CIntPtr where { toRational = P.toRational }
instance Integral CIntPtr where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CIntPtr where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CUIntPtr where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CUIntPtr where { toRational = P.toRational }
instance Integral CUIntPtr where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CUIntPtr where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CIntMax where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CIntMax where { toRational = P.toRational }
instance Integral CIntMax where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CIntMax where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CUIntMax where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CUIntMax where { toRational = P.toRational }
instance Integral CUIntMax where { quot = P.quot; rem = P.rem; div = P.div; mod = P.mod; quotRem = P.quotRem; divMod = P.divMod; toInteger = P.toInteger }
instance Bits CUIntMax where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Num CClock where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CClock where { toRational = P.toRational }
instance Num CTime where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CTime where { toRational = P.toRational }
instance Num CFloat where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CFloat where { toRational = P.toRational }
instance Fractional CFloat where { (/) = (P./); recip = P.recip; fromRational = P.fromRational }
instance Floating CFloat where { pi = P.pi; exp = P.exp; log = P.log; sqrt = P.sqrt; (**) = (P.**); logBase = P.logBase; sin = P.sin; cos = P.cos; tan = P.tan; asin = P.asin; acos = P.acos; atan = P.atan; sinh = P.sinh; cosh = P.cosh; tanh = P.tanh; asinh = P.asinh; acosh = P.acosh; atanh = P.atanh }
instance RealFrac CFloat where { properFraction x = case P.properFraction x of { (n, f) -> (fromInteger n, f) }; truncate x = fromInteger (P.truncate x); round x = fromInteger (P.round x); ceiling x = fromInteger (P.ceiling x); floor x = fromInteger (P.floor x) }
instance RealFloat CFloat where { floatRadix = P.floatRadix; floatDigits = P.floatDigits; floatRange = P.floatRange; decodeFloat = P.decodeFloat; encodeFloat = P.encodeFloat; isNaN = P.isNaN; isInfinite = P.isInfinite; isDenormalized = P.isDenormalized; isNegativeZero = P.isNegativeZero; isIEEE = P.isIEEE }
instance Num CDouble where { (+) = (P.+); (-) = (P.-); (*) = (P.*); negate = P.negate; abs = P.abs; signum = P.signum; fromInteger = P.fromInteger }
instance Real CDouble where { toRational = P.toRational }
instance Fractional CDouble where { (/) = (P./); recip = P.recip; fromRational = P.fromRational }
instance Floating CDouble where { pi = P.pi; exp = P.exp; log = P.log; sqrt = P.sqrt; (**) = (P.**); logBase = P.logBase; sin = P.sin; cos = P.cos; tan = P.tan; asin = P.asin; acos = P.acos; atan = P.atan; sinh = P.sinh; cosh = P.cosh; tanh = P.tanh; asinh = P.asinh; acosh = P.acosh; atanh = P.atanh }
instance RealFrac CDouble where { properFraction x = case P.properFraction x of { (n, f) -> (fromInteger n, f) }; truncate x = fromInteger (P.truncate x); round x = fromInteger (P.round x); ceiling x = fromInteger (P.ceiling x); floor x = fromInteger (P.floor x) }
instance RealFloat CDouble where { floatRadix = P.floatRadix; floatDigits = P.floatDigits; floatRange = P.floatRange; decodeFloat = P.decodeFloat; encodeFloat = P.encodeFloat; isNaN = P.isNaN; isInfinite = P.isInfinite; isDenormalized = P.isDenormalized; isNegativeZero = P.isNegativeZero; isIEEE = P.isIEEE }
instance Bits Int where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
instance Bits Integer where { (.&.) = (B..&.); (.|.) = (B..|.); xor = B.xor; complement = B.complement; shift = B.shift; rotate = B.rotate; bit = B.bit; setBit = B.setBit; clearBit = B.clearBit; complementBit = B.complementBit; testBit = B.testBit; bitSize = B.bitSize; isSigned = B.isSigned; shiftL = B.shiftL; shiftR = B.shiftR; rotateL = B.rotateL; rotateR = B.rotateR }
