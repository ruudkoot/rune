-- Report 16.1, Figure 16.1: inner of inconformable arrays is an error.
module Main (main) where

import Array

inner :: (Ix a, Num b) => Array a b -> Array a b -> b
inner v w = if b == bounds w then sum [v ! i * w ! i | i <- range b]
            else error "inconformable arrays for inner product"
  where b = bounds v

main :: IO ()
main = do
  putStrLn "before"
  print (inner (listArray (1, 2) [1, 2]) (listArray (0, 1) [3, 4 :: Int]))
