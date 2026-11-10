-- Report 1.2: a program using type classes and polymorphic types compiles.
module Main (main) where

class C a where
  c :: a -> Int
instance C Bool where
  c _ = 1

f :: (C a) => [a] -> Int
f = sum . map c

g :: [b] -> Int
g = length

main :: IO ()
main = return ()
