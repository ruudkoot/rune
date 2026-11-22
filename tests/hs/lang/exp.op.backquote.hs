-- rows: exp.op.default.fixity exp.op.paren exp.op.paren.foldr exp.op.nofixity.paren
-- Report 3.2: x `op` y is op x y; an operator with no fixity declaration is infixl 9; (+) is an ordinary identifier, and
-- its fixity has no effect there.
module Main (main) where

op :: Int -> Int -> Int
op x y = 10 * x + y

(&) :: Int -> Int -> Int
x & y = x - y

f :: (Int -> Int -> Int) -> (Int -> Int -> Int) -> Int -> Int
f g h z = g z (h z z)

main :: IO ()
main = do
  print (1 `op` 2, op 1 2)
  print (10 & 3 & 2, 2 * 5 & 3, 1 + 4 & 2)
  print (1 `op` 2 `op` 3, 2 * 1 `op` 2)
  print ((+) 1 2, 1 + 2)
  print (foldr (*) 1 [1, 2, 3, 4], foldr (\x y -> x * y) 1 [1, 2, 3, 4])
  print (f (+) (*) 3)
