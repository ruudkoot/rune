-- rows: dec.bind.both.local dec.fun.where.scope dec.fun.where.patvars tr.dec.fun.semantic
-- Report 4.4.3: function and pattern bindings at the top and in let and where; a where scopes over a clause's guards and
-- bodies and sees its pattern variables; a function binding is not restricted, though its translation is a
-- pattern binding.
module Main (main) where

f :: Int -> Int
f x | y > 0 = y
    | otherwise = y + 1
  where y = x

(a, b) = (1 :: Int, 2 :: Int)

plus x y = x + y

main :: IO ()
main = do
  print (f 1, a + b, let { g z = z ; (c, d) = (3, 4) } in g c + d)
  print (h 5, plus 1 2, plus 1.5 2)
  where
    h z = z
    (e, _) = (6, 7)
