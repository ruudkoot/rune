-- Report 8: a bottom probe of seq, the Report's own definition its reference: seq (Just u) (1 :: Int) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (seq (Just u) (1 :: Int))
