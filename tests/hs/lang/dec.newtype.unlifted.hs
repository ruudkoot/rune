-- Report 4.2.3: a newtype adds no level: seq (N undefined) 1 diverges.
module Main (main) where

newtype N = N Int

main :: IO ()
main = print (seq (N undefined) (1 :: Int))
