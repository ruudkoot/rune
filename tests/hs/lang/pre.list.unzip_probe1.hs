-- Report 8: a bottom probe of unzip, the Report's own definition its reference: head (fst (unzip ((1 :: Int, u) : undefined))) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (head (fst (unzip ((1 :: Int, u) : undefined))))
