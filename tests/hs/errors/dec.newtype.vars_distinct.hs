-- Report 4.2.3, with 4.2.1's rules: the variables are distinct.
module Main (main) where

newtype T a a = C a

main :: IO ()
main = return ()
