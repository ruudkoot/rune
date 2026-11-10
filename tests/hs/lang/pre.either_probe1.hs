-- Report 8: a bottom probe of either, the Report's own definition its reference: either (const (1 :: Int)) (const 2) (Left u :: Either Int Int) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (either (const (1 :: Int)) (const 2) (Left u :: Either Int Int))
