-- Report 17.9: a bottom probe of unzip5, the Report's own definition its reference: let (_, b, _, _, _) = unzip5 [(u, 2 :: Int, u, u, u), undefined] in b is bottom;
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
  mapM_ print (take 5 (let (_, b, _, _, _) = unzip5 [(u, 2 :: Int, u, u, u), undefined] in b))
