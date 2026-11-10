-- rows: lay.intro.meaning lay.informal.keywords lay.informal.newitem lay.informal.close
-- Report 2.7: "Haskell permits the omission of the braces and semicolons used in several grammar productions, by using
-- layout"; it takes effect after where, let, do and of: each here, laid out, beside its form in braces.
module Main (main) where

class C a where
  m :: a -> Int
  m _ = 0

instance C Bool where
  m b = if b then 1 else 0

f :: Int -> Char
f x = case x of
  1 -> c
    where c = 'a'
  _ -> 'b'

f' :: Int -> Char
f' x = case x of { 1 -> c where { c = 'a' }; _ -> 'b' }

g :: Int -> Int
g y = let a = y
          b = 2
      in a + b

g' :: Int -> Int
g' y = let { a = y; b = 2 } in a + b

main :: IO ()
main = do
  print (f 1, f' 1)
  print (g 1, g' 1, m True)
