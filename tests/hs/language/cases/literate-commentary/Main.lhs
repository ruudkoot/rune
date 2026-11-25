{-# LANGUAGE Haskell2010 #-} is commentary here, which unlit blanks

> module Main (main) where
> pred' :: Integer -> Integer
> pred' (n+1) = n
> main :: IO ()
> main = print (pred' 3)
