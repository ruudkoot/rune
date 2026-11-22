-- rows: dec.fun.lhs.var dec.fun.lhs.infix dec.fun.lhs.paren dec.fun.lhs.nestedparen dec.note.pat0
-- Report 4.4.3: a binding is a pattern binding where its left side is a pat0, else a function binding: the four examples
-- of 4.4.3.2's note; funlhs as a variable with patterns, an infix definition, and parenthesised forms, nested.
module Main (main) where

plus :: Int -> Int -> Int
x `plus` y = x + y

f :: Int -> [Int] -> Int
f x (y:ys) = x + y
f x [] = x

(g x) y = x + y :: Int
((h x) y) z = x + y + z :: Int
(x `q` y) z = x + y + z :: Int

main :: IO ()
main = print (r, s, 1 `plus` 2, f 1 [2], (g 1 2, h 1 2 3, q 1 2 3))
  where
    x + 1 = (x :: Int)
    r = 4 + 1
    (y + 1) = 3 :: Int
    s = y
