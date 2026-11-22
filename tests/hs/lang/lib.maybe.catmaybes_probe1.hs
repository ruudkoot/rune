-- Report 18.1: a bottom probe of catMaybes, the Report's own definition its reference: catMaybes [Just 1, Nothing, Just 2, undefined] is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import Maybe

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (catMaybes [Just 1, Nothing, Just 2, undefined]))
