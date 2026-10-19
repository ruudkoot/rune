module Main where
import GHC.Float(castWord32ToFloat)
import Data.Word(Word32)
values :: [Word32]
values=[0,0x80000000,1,0x80000001,0x7f800000,0xff800000,0x7fc00000,
 0x007fffff,0x00800000,0x3f800000,0x3dcccccd,0x3c23d70a,0x4b7fffff,0x4b800000,0x7f7fffff]
 ++take 10000(iterate(\w->w*1103515245+12345)0xF10D)
main=mapM_(\w->putStrLn(show w++"|"++show(castWord32ToFloat w)))values
