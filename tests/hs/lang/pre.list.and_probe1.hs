-- Report 8: a bottom probe of and, the Report's own definition its reference: and (False : undefined) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (and (False : undefined))
