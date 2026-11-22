-- Report 13: :+ is strict: a bottom imaginary part makes the number bottom.
module Main (main) where

import Complex

main :: IO ()
main = do
  putStrLn "probe"
  print ((1 :+ undefined :: Complex Double) `seq` ())
