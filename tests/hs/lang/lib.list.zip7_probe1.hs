-- Report 17.9: a bottom probe of zip7, the Report's own definition its reference: length (zip7 [1, 2] [3] [u] [u] [u] [u] [u]) is not;
-- a marker, then the term.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (zip7 [1, 2] [3] [u] [u] [u] [u] [u]))
