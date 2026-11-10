-- Report 3.17.2: (\ (x:xs) -> x:x:xs) bottom is bottom.
module Main (main) where

main :: IO ()
main = print (case (\(x : xs) -> x : x : xs) (undefined :: [Int]) of { (_ : _) -> 1; _ -> 2 :: Int })
