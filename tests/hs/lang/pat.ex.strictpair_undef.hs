-- rows: pat.ref.singlecon pat.ref.others
-- Report 3.17.2: (\ (x,y) -> 0) bottom is bottom: a tuple pattern is refutable.
module Main (main) where

main :: IO ()
main = print ((\(x, y) -> 0 :: Int) (undefined :: (Int, Int)))
