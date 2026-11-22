-- Report 8: a bottom probe of takeWhile, the Report's own definition its reference: takeWhile (< 3) (1 : 2 : 3 : ul) is not;
-- a marker, then the term, element by element.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (takeWhile (< 3) (1 : 2 : 3 : ul)))
