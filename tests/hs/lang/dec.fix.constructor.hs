-- rows: dec.fix.pattern
-- Report 4.4.2: infixr 5 :+: for a constructor holds in expressions and in patterns: a :+: b :+: c nests right.
module Main (main) where

infixr 5 :+:
data T = L Int | T :+: T

f :: T -> String
f (L a :+: (L b :+: L c)) = "right"
f ((L a :+: L b) :+: L c) = "left"
f _ = "other"

g :: T -> Int
g (a :+: b :+: c) = 1
g _ = 0

main :: IO ()
main = print (f (L 1 :+: L 2 :+: L 3), g (L 1 :+: L 2 :+: L 3), g ((L 1 :+: L 2) :+: L 3))
