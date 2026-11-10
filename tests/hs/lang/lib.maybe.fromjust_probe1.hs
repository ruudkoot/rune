-- Report 18.1: a bottom probe of fromJust, the Report's own definition its reference: length [fromJust (Just u)] is not;
-- a marker, then the term.
module Main (main) where

import Maybe

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length [fromJust (Just u)])
