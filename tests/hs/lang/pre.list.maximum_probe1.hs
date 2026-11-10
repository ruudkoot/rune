-- Report 8: a bottom probe of maximum, the Report's own definition its reference: maximum [1, u] is bottom;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (maximum [1, u])
