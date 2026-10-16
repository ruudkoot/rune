module Main where
import Mandel
import PortablePixmap
import System.Environment
main=do
 [sw,sh,sl]<-getArgs
 let w=read sw;h=read sh;limit=read sl
 case mandelset (-2) (-2) 2 2 w h limit of
  Pixmap a b c pixels->do
   putStrLn(unwords[show a,show b,show c])
   mapM_(\(r,g,b)->putStrLn(unwords[show r,show g,show b]))pixels
