-- rows: mod.shadow.myprelude.tuple mod.shadow.myprelude.list
-- Report 5.6.2: with MyPrelude in the Prelude's place, ++ is MyPrelude's, while tuples and lists keep the Prelude's syntax.
module Main (main) where

import Prelude ()
import MyPrelude

main :: IO ()
main = do
  print ([1] ++ [2 :: Int])
  print (fst (1 :: Int, 'a'), (,) True 'b')
  print (length [1, 2 :: Int], [] == ([] :: [Int]))
