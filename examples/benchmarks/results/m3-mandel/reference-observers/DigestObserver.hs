module Main where
import Mandel
import PortablePixmap
import Data.Word
import Data.List
import Data.Char
import Numeric
import System.Environment
mix :: Word64 -> Int -> Word64
mix h value=h*1664525+fromIntegral value
main=do
 [sw,sh,sl]<-getArgs
 case mandelset (-2) (-2) 2 2(read sw)(read sh)(read sl)of
  Pixmap w h cap pixels->do
   let hash=foldl'(\acc(r,g,b)->mix(mix(mix acc r)g)b)1013904223 pixels
   putStrLn(unwords[show w,show h,show cap,show(length pixels),map toUpper(showHex hash "")])
