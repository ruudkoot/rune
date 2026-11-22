-- Report 8: a bottom probe of elem, the Report's own definition its reference: elem 1 (1 : ul) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (elem 1 (1 : ul))
