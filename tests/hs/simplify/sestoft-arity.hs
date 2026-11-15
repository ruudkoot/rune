-- A function of two parameters matched by clauses, or by a lambda of two
-- patterns, is a function of two arguments: given one, even bottom, it is
-- a value (4.4.3.1, 3.3), where a function of one parameter returning a
-- lambda is bottom given bottom. Sestoft's trees (D34's B) keep the
-- arity, at -O2 too.
-- sestoft: as A
module Main where

f :: Bool -> Int -> Int
f True x = x

g :: Bool -> Int -> Int
g True = \x -> x

lam :: Bool -> Int -> Int
lam = \True x -> x

main :: IO ()
main = do
  f undefined `seq` putStrLn "f undefined is a function"
  lam undefined `seq` putStrLn "lam undefined is a function"
  print (f True 1, g True 2, lam True 3)
  g undefined `seq` putStrLn "g undefined is not a value"
