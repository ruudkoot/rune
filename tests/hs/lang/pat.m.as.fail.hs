-- Report 3.17.2: x@p matches as p does, binding x: against another constructor it fails.
module Main (main) where

main :: IO ()
main = print (case Nothing :: Maybe Int of { x@(Just _) -> 1; _ -> 2 :: Int })
