-- Report 17.9: a bottom probe of delete, the Report's own definition its reference: length (delete 1 [1, u]) is not;
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
  print (length (delete 1 [1, u]))
