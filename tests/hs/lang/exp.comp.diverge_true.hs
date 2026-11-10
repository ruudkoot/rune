-- Report 3.11: a generator's pattern matched against bottom diverges: [1 | True <- [undefined]].
module Main (main) where

main :: IO ()
main = print (length [1 | True <- [undefined]])
