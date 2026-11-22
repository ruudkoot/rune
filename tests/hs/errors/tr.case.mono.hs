-- Report 3.17.3: a case binds monomorphically: case id of f -> (f 1, f 'a').
module Main (main) where

p = case id of f -> (f 1, f 'a')

main :: IO ()
main = return ()
