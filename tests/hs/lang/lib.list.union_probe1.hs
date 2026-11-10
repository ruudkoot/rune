-- Report 17.9: a bottom probe of union, the Report's own definition its reference: union (1 : 2 : ul) [3] is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (union (1 : 2 : ul) [3]))
