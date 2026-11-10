-- Report 8: a bottom probe of map, the Report's own definition its reference: map (const (1 :: Int)) [u, u] is not;
-- a marker, then the term, element by element.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (map (const (1 :: Int)) [u, u]))
