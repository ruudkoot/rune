module M3 (len3) where

default (Int, Double)

genericLength :: Num a => [b] -> a
genericLength = foldr (\_ n -> n + 1) 0

len3 :: Num a => a
len3 = genericLength "Hello"
