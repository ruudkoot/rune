-- Report 17.9: a bottom probe of genericReplicate, the Report's own definition its reference: length (genericReplicate (2 :: Integer) u) is not;
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
  print (length (genericReplicate (2 :: Integer) u))
