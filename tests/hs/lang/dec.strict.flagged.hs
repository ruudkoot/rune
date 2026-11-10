-- Report 4.2.1: a strict field forces its argument: case D undefined of D _ -> 1 diverges.
module Main (main) where

data D = D !Int

main :: IO ()
main = print (case D undefined of D _ -> (1 :: Int))
