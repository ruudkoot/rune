module Patterns where

-- Every form of pattern of 3.17 and of a function's left-hand side, 4.4.3.
f x _ 0 'c' "s" 1.5 = 1
f (-1) (- 2) (x : xs) (a, b) [c, d] [] () = 2
f ~(a, b) all@(x : _) (Just y) (Left (Right z)) (P{}) (P { px = 1, py = q }) n = 3
f (n + 1) ((m)) ((:) u v) (u :+ v) (u `Pair` v) ~(~w) x@ ~y = 4
g ((n+2)) = n

-- Infix and parenthesised left-hand sides.
x <+> y = x
(x `op` y) z = z
(f2 . g2) x = x
(a :+ b) .+. (c :+ d) = a
infixl 6 .+.
x `op` y = x
Just a ==> b = b
(<<<) a b = a

data P = P { px :: Int, py :: Int }
data C = Int :+ Int | Pair Int Int

-- Patterns in lambdas, case, do, let and comprehensions.
h = \(Just x) ~[y] -> [z | (z, _) <- [(x, y)]]
k v = case v of
  Just (x, y) | x > y -> x
  ~(Just _) -> 0
  _ -> 1
m = do
  (a, b) <- return (1, 2)
  ~[c] <- return [3]
  let (d, e) = (4, 5)
      Just f = Nothing
  return a
