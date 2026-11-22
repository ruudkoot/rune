-- Report 17.9: a bottom probe of sort, the Report's own definition its reference: length (sort [u]) is not;
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
  print (length (sort [u]))
