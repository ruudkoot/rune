-- Report 20.4: a bottom probe of mapAndUnzipM, the Report's own definition its reference: maybe [] fst (mapAndUnzipM (\x -> Just (x, u)) [1, 2]) is not;
-- a marker, then the term, element by element.
module Main (main) where

import Monad

u :: Int
u = undefined

ul :: [Int]
ul = undefined

main :: IO ()
main = do
  putStrLn "probe"
  mapM_ print (take 5 (maybe [] fst (mapAndUnzipM (\x -> Just (x, u)) [1, 2])))
