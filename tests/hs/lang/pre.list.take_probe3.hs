-- Report 8: a bottom probe of take, the Report's own definition its reference: take 3 (1 : ul) is bottom;
-- a marker, then the term, element by element.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (take 3 (1 : ul)))
