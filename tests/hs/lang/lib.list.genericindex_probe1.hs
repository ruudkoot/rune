-- Report 17.9: a bottom probe of genericIndex, the Report's own definition its reference: genericIndex [u, 2] (1 :: Integer) is not;
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
  print (genericIndex [u, 2] (1 :: Integer))
