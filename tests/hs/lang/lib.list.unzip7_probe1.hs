-- Report 17.9: a bottom probe of unzip7, the Report's own definition its reference: let (_, _, _, _, _, _, g) = unzip7 [(u, u, u, u, u, u, 7 :: Int), (u, u, u, u, u, u, 8)] in g is not;
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
  mapM_ print (take 5 (let (_, _, _, _, _, _, g) = unzip7 [(u, u, u, u, u, u, 7 :: Int), (u, u, u, u, u, u, 8)] in g))
