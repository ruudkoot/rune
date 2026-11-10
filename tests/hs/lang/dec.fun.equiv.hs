-- rows: dec.fun.clauses dec.fun.guards dec.fun.guards.fallthrough dec.fun.shorthand
-- Report 4.4.3: the forms of a function binding are equivalent; clauses are tried in order, the first that matches taken;
-- a guard that fails falls through to the next clause; f x = e is f = \x -> e.
module Main (main) where

plus1, plus2, plus3 :: Int -> Int -> Int -> Int
plus1 x y z = x + y + z
x `plus2` y = \z -> x + y + z
(x `plus3` y) z = x + y + z

c :: Int -> String
c 0 = "zero"
c 0 = "never"
c n | n < 0 = "neg"
c n | n > 100 = "big"
c _ = "small"

sq1, sq2 :: Int -> Int
sq1 x = x * x
sq2 = \x -> x * x

main :: IO ()
main = do
  print (plus1 1 2 3, plus2 1 2 3, plus3 1 2 3)
  print (map c [0, -1, 200, 5])
  print (map sq1 [2, 3], map sq2 [2, 3])
