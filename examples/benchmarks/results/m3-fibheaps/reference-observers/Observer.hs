module Main where
import qualified Kernel as K
import System.Environment
import Data.List (group)
main = do
  args <- getArgs
  let n=read(head args)
      a=K.fibSort(K.randoms n)
      b=K.fibSort'(K.randoms n)
  if a/=b then error "heap algorithms differ" else do
    mapM_ (\xs -> putStrLn(show(head xs)++" "++show(length xs))) (group a)
