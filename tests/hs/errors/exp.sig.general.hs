-- Report 3.16: a signature may not be more general than the principal type.
module Main (main) where

x = 'a' :: a

main :: IO ()
main = return ()
