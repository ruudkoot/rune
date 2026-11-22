-- Report 8: a bottom probe of sum, the Report's own definition its reference: sum (1 : ul) is bottom;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (sum (1 : ul))
