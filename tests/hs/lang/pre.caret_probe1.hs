-- Report 8: a bottom probe of ^, the Report's own definition its reference: (^) u (0 :: Int) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print ((^) u (0 :: Int))
