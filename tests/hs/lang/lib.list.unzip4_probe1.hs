-- Report 17.9: a bottom probe of unzip4, the Report's own definition its reference: let (a, _, _, _) = unzip4 ((1 :: Int, u, u, u) : undefined) in head a is not;
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
  print (let (a, _, _, _) = unzip4 ((1 :: Int, u, u, u) : undefined) in head a)
