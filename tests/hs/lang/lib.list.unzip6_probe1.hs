-- Report 17.9: a bottom probe of unzip6, the Report's own definition its reference: let (_, _, _, _, _, f) = unzip6 ((u, u, u, u, u, 6 :: Int) : undefined) in head f is not;
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
  print (let (_, _, _, _, _, f) = unzip6 ((u, u, u, u, u, 6 :: Int) : undefined) in head f)
