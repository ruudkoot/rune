-- Report 4.3.4: show [] has no numeric class either.
module Main (main) where

main :: IO ()
main = putStrLn (show [])
