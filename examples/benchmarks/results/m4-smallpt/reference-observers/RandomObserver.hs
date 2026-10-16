module Main where
import qualified Kernel as K
import Numeric(showHex)
main = mapM_ one [0,1,11,47,383]
 where
  one y = loop y 0 (K.mkErand48Seed' y)
  loop _ 10 _ = return ()
  loop y i state = do
   let (next,value)=K.erand48' state
   putStrLn(show y++" "++show i++" "++showHex next ""++" "++show value)
   loop y (i+1) next
