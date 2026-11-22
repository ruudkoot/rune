-- Report 17.9: a bottom probe of unionBy, the Report's own definition its reference: unionBy (\_ _ -> True) [1] ul is bottom;
-- a marker, then the term, element by element.
module Main (main) where

import List

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (unionBy (\_ _ -> True) [1] ul))
