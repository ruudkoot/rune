-- Report 8: a bottom probe of head, the Report's own definition its reference: head (1 : ul) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (head (1 : ul))
