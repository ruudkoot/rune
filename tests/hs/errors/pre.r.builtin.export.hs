-- Report 8: the built-in types cannot appear in an export list: [].
module Main (main, []) where

main :: IO ()
main = return ()
