-- Report 17.9: a bottom probe of maximumBy, the Report's own definition its reference: maximumBy (\_ _ -> GT) [1, u] is not;
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
  print (maximumBy (\_ _ -> GT) [1, u])
