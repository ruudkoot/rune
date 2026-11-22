-- Report 8: a bottom probe of scanl, the Report's own definition its reference: take 2 (scanl (+) 0 (1 : ul)) is not;
-- a marker, then the term, element by element.
module Main (main) where

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (take 2 (scanl (+) 0 (1 : ul))))
