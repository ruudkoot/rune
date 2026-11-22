-- Report 4.2.2: nor where the kind would fit: App (P Int).
module Main (main) where

type P a b = (a, b)
data App f = A (f Int)

x :: App (P Int)
x = A (1, 2)

main :: IO ()
main = return ()
