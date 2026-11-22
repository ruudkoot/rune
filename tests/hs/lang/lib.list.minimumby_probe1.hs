-- Report 17.9: a bottom probe of minimumBy, the Report's own definition its reference: minimumBy (\_ _ -> GT) [u, 2] is not;
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
  print (minimumBy (\_ _ -> GT) [u, 2])
