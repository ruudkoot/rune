-- rows: exp.let.rec exp.let.lexical exp.let.lazy exp.let.pat.novar tr.let.pre tr.let.tuple tr.let.case tr.let.fix R17
-- Report 3.12: let is lexically scoped, mutually recursive and lazy; its pattern bindings are matched lazily, even one
-- with no variable; the translations of function bindings, of a pattern binding, and of a recursive one.
module Main (main) where

main :: IO ()
main = do
  print (let {} in 1 :: Int)
  print (let ev 0 = True
             ev n = od (n - 1)
             od 0 = False
             od n = ev (n - 1)
         in ev (10 :: Int))
  print (let xs = 1 : ys
             ys = 2 : xs
         in take 5 xs :: [Int])
  print (let x = 1 in let x = 2 in x :: Int)
  print (let (x, y) = undefined in 1 :: Int)
  print (let Just x = Nothing in 1 :: Int)
  print (let True = False in 1 :: Int)
  print (let f x | x > 0 = 1
               | otherwise = 2
         in (f 1, f 0) :: (Int, Int))
  print (let f = \x -> if x > 0 then 1 else 2 in (f 1, f 0) :: (Int, Int))
  print (let (a, b) = (1 :: Int, 2 :: Int) in a + b, case (1 :: Int, 2 :: Int) of ~(a, b) -> a + b)
  print (let (a, b) = (1 :: Int, a + 1) in b)
