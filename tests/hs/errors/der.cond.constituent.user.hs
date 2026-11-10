-- Report 10: a user type with no instance cannot be a constituent of a derived Show.
module Main (main) where

data U = U

data T = T U deriving Show

main :: IO ()
main = return ()
