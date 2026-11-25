> {-# LANGUAGE Haskell2010 #-}
> module Main (main) where
> pred' :: Integer -> Integer
> pred' (n+1) = n
> main :: IO ()
> main = print (pred' 3)
