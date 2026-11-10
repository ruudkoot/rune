-- Report 8: a bottom probe of snd, the Report's own definition its reference: snd (u, 2 :: Int) is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (snd (u, 2 :: Int))
