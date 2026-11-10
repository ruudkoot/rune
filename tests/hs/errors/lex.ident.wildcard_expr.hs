-- Report 2.4: "_ all by itself is a reserved identifier, used as wild card in patterns": not an expression.
module Main (main) where

x :: Int
x = _

main :: IO ()
main = return ()
