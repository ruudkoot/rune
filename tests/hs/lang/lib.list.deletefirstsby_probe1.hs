-- Report 17.9: a bottom probe of deleteFirstsBy, the Report's own definition its reference: length (deleteFirstsBy (\_ _ -> True) [u, u, u] [u]) is not;
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
  print (length (deleteFirstsBy (\_ _ -> True) [u, u, u] [u]))
