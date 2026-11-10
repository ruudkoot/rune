-- Report 8: a bottom probe of last, the Report's own definition its reference: last [u, 2] is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (last [u, 2])
