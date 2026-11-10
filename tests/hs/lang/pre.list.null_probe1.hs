-- Report 8: a bottom probe of null, the Report's own definition its reference: null (u : ul) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (null (u : ul))
