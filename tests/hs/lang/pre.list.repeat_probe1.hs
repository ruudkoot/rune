-- Report 8: a bottom probe of repeat, the Report's own definition its reference: length (take 2 (repeat u)) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (length (take 2 (repeat u)))
