-- Report 17.9: infix 5 \\: it binds tighter than (==), (<) and `elem` (4), looser than application, and $ (0) takes it whole.
module Main (main) where

import List

main :: IO ()
main = do
  print ([1, 2, 3] \\ [2] == [1, 3 :: Int], [1, 2, 3] \\ [2] < [1, 4 :: Int], 2 `elem` [1, 2, 3] \\ [2 :: Int])
  print (length $ "abc" \\ "b", [1, 2, 3] \\ map (+ 1) [1 :: Int], reverse "abc" \\ "c")
