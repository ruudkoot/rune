-- Report 8: a bottom probe of reverse, the Report's own definition its reference: length (reverse [u, u]) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (reverse [u, u]))
