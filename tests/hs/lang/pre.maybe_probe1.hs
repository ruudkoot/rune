-- Report 8: a bottom probe of maybe, the Report's own definition its reference: maybe 0 (const (1 :: Int)) (Just u) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (maybe 0 (const (1 :: Int)) (Just u))
