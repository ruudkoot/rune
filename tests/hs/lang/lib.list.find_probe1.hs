-- Report 17.9: a bottom probe of find, the Report's own definition its reference: find even (1 : 2 : ul) is not;
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
  print (find even (1 : 2 : ul))
