-- Report 4.2.3, with 4.2.1's rules: no other variable stands on the right.
module Main (main) where

newtype T a = C b

main :: IO ()
main = return ()
