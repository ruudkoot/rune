-- Report 8: a bottom probe of words, the Report's own definition its reference: head (words ('a' : ' ' : undefined)) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (head (words ('a' : ' ' : undefined)))
