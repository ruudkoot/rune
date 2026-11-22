-- Report 17.9: a bottom probe of unfoldr, the Report's own definition its reference: length (unfoldr (\n -> if n > 2 then Nothing else Just (u, n + 1)) (0 :: Int)) is not;
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
  print (length (unfoldr (\n -> if n > 2 then Nothing else Just (u, n + 1)) (0 :: Int)))
