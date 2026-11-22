-- Report 3.3: a lambda binds monomorphically.
module Main (main) where

p = (\f -> (f 1, f 'a')) id

main :: IO ()
main = return ()
