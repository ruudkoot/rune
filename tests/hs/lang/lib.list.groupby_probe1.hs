-- Report 17.9: a bottom probe of groupBy, the Report's own definition its reference: length (take 2 (groupBy (\_ _ -> False) [u, u, u])) is not;
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
  print (length (take 2 (groupBy (\_ _ -> False) [u, u, u])))
