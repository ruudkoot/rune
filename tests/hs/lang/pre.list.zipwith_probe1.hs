-- Report 8: a bottom probe of zipWith, the Report's own definition its reference: zipWith (+) [] ul is not;
-- a marker, then the term, element by element.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (zipWith (+) [] ul))
