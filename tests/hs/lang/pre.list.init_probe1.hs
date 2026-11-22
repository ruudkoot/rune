-- Report 8: a bottom probe of init, the Report's own definition its reference: length (init [u, u, u]) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (init [u, u, u]))
