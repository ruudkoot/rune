module M1 (len1) where

default (Int, Double)

genericLength :: Num a => [b] -> a
genericLength = foldr (\_ n -> n + 1) 0

len1 = genericLength "Hello"
