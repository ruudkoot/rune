-- Report 2.4, the table of samples: `f..` lexes as `f ..`, two tokens, here an arithmetic sequence.
module Main (main) where

main :: IO ()
main = print (take 3 [f..])
  where f = 1 :: Int
