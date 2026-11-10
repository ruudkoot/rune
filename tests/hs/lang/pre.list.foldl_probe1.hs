-- Report 8: a bottom probe of foldl, the Report's own definition its reference: foldl (\_ x -> x) 0 [u, 2] is not;
-- a marker, then the term.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (foldl (\_ x -> x) 0 [u, 2])
