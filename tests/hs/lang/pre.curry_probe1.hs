-- Report 8: a bottom probe of curry, the Report's own definition its reference: curry fst (1 :: Int) u is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (curry fst (1 :: Int) u)
