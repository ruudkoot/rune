-- Report 1.4: a type constructor is upper-case: data t = C is refused.
module Main (main) where

data t = C

main :: IO ()
main = return ()
