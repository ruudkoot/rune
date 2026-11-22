-- Report 6.3.2: IOError is not in Ord.
module Main (main) where

x :: Bool
x = userError "a" < userError "b"

main :: IO ()
main = return ()
