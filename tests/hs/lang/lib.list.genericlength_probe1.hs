-- Report 17.9: a bottom probe of genericLength, the Report's own definition its reference: genericLength [u, u] :: Integer is not;
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
  print (genericLength [u, u] :: Integer)
