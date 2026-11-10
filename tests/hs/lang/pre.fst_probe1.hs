-- Report 8: a bottom probe of fst, the Report's own definition its reference: fst (1 :: Int, u) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (fst (1 :: Int, u))
