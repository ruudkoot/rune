-- Report 4.2.1, 4.2.3: not in a newtype: newtype N = N !Int.
module Main (main) where

newtype N = N !Int

main :: IO ()
main = return ()
