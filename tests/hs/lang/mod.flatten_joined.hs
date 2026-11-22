-- Report 5: the three modules of mod.flatten_modules as one, by renaming and concatenation: the same output.
module Main (main) where

af :: IO ()
af = putStrLn "A"

ag :: Int -> Int
ag x = x * 10

bf :: IO ()
bf = putStrLn "B"

main :: IO ()
main = af >> bf >> print (ag 2)
