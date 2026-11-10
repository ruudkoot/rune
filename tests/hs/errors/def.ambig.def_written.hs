-- Report 4.3.4: a type whose context mentions a variable its type does not is invalid.
module Main (main) where

f :: Show a => Int
f = 0

main :: IO ()
main = return ()
