-- Report 4.5.5 Rule 2: a restricted variable is defaulted when the whole module has been checked: x = 1 is a Double, as y
-- uses it so.
module Main (main) where

x = 1

y = x + 1.5

main :: IO ()
main = print x
