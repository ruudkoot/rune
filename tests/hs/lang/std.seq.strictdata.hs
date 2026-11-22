-- Report 6.2, 4.2.1: a strict field's constructor applied to bottom is bottom.
module Main (main) where

data D = D !Int

main :: IO ()
main = print (seq (D undefined) (1 :: Int))
