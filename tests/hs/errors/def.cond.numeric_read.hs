-- Report 4.3.4: one of the classes is numeric: show (read "1") has none.
module Main (main) where

main :: IO ()
main = putStrLn (show (read "1"))
