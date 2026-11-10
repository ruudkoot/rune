-- Report 3.17.2: x@p against bottom diverges where p does.
module Main (main) where

main :: IO ()
main = print (case undefined :: Maybe Int of { x@(Just _) -> 1; _ -> 2 :: Int })
