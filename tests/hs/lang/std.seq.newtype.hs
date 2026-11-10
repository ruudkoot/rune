-- Report 6.2, 4.2.3: a newtype's constructor applied to bottom is bottom: seq (N undefined) 1 diverges.
module Main (main) where

newtype N = N Int

main :: IO ()
main = print (seq (N undefined) (1 :: Int))
