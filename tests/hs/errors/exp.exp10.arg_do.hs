-- Report 3: a do is an exp10, so no unparenthesised argument: f do {x}.
module Main (main) where

x :: Maybe Int
x = id do { Just 1 }

main :: IO ()
main = return ()
