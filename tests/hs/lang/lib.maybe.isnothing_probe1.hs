-- Report 18.1: a bottom probe of isNothing, the Report's own definition its reference: isNothing (Just u) is not;
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
  print (isNothing (Just u))
