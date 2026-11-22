-- Report 4.2.3: a newtype is a distinct type: an Int is no N.
module Main (main) where

newtype N = N Int

x :: N
x = 1 :: Int

main :: IO ()
main = return ()
