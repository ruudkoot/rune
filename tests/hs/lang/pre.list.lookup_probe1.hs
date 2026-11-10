-- Report 8: a bottom probe of lookup, the Report's own definition its reference: lookup (1 :: Int) ((1, 'a') : undefined) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (lookup (1 :: Int) ((1, 'a') : undefined))
