-- Report 10, 4.2.3: a newtype derives only what data could: Enum is refused for N Int.
module Main (main) where

newtype N = N Int deriving Enum

main :: IO ()
main = return ()
