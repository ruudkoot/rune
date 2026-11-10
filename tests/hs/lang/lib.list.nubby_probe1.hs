-- Report 17.9: a bottom probe of nubBy, the Report's own definition its reference: length (nubBy (\_ _ -> False) [u, u]) is not;
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
  print (length (nubBy (\_ _ -> False) [u, u]))
