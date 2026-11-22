-- Report 3.17.3: and with ~ too.
module Main (main) where

p = case id of ~f -> (f 1, f 'a')

main :: IO ()
main = return ()
