-- Report 17.9: a bottom probe of isPrefixOf, the Report's own definition its reference: isPrefixOf [1, 2] (1 : 3 : ul) is not;
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
  print (isPrefixOf [1, 2] (1 : 3 : ul))
