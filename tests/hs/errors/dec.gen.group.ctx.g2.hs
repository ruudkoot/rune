-- Report 4.5.2: g2 is overloaded as g1, with Show, so not at a type with no Show.
module Main (main) where

g1 x y = if x > y then show x else g2 y x
g2 p q = g1 q p

data T = T deriving (Eq, Ord)

z :: String
z = g2 T T

main :: IO ()
main = return ()
