-- Report 4.3.4: an expression of an ambiguous type is ill-typed: show (read ...).
module Main (main) where

main :: IO ()
main = putStrLn (let x = read "1" in show x)
