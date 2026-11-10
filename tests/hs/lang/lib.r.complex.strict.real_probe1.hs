-- Report 13: :+ is strict: a bottom real part makes the number bottom.
module Main (main) where

import Complex

main :: IO ()
main = do
  putStrLn "probe"
  print ((undefined :+ 1 :: Complex Double) `seq` ())
