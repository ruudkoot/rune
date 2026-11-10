-- rows: lib.array.array R155
-- Report 16.1 (overlay ov.array.strictbounds, the lead's ruling 35, R155; M17's bottom probes on the literal
-- Prelude): array strict in its bounds; the reference is the printed array under another name, which checks the
-- bounds only through inRange over the associations. They agree on every term but the last, where the printed code
-- gives () (ruling 35's difference: the prose decides). A marker, then the terms; the last is bottom.
module Main (main) where

import Array

i :: Int
i = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (bounds (array (1, 3 :: Int) [] :: Array Int Char), (array (1, 0 :: Int) [] :: Array Int Char) `seq` ())
  print (bounds (listArray (5, 4 :: Int) [] :: Array Int Int), (array (1, 2 :: Int) [(1, 'a')]) `seq` ())
  print ((array (1, i) [] :: Array Int Char) `seq` ())
