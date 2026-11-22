-- rows: prag.inline R52 R92
-- Report 10.4, readings.md R92: Figure 10.1's Tree with infixr 5 :^: and its numbers; the INLINE pragma on
-- a factorial whose base case is factorial 0 = 1.
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a

instance (Show a) => Show (Tree a) where
  showsPrec d (Leaf m) = showParen (d > app_prec) showStr
    where showStr = showString "Leaf " . showsPrec (app_prec + 1) m
  showsPrec d (u :^: v) = showParen (d > up_prec) showStr
    where showStr = showsPrec (up_prec + 1) u . showString " :^: " . showsPrec (up_prec + 1) v

app_prec, up_prec :: Int
app_prec = 10
up_prec = 5

factorial :: Integer -> Integer
{-# INLINE factorial #-}
factorial 0 = 1
factorial n = n * factorial (n - 1)

main :: IO ()
main = print (Leaf (factorial 3) :^: Leaf 1)
