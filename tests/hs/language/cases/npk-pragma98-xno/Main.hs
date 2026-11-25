{-# LANGUAGE Haskell98 #-}
module Main (main) where

fact :: Integer -> Integer
fact 0 = 1
fact (n+1) = (n+1) * fact n

main :: IO ()
main = print (fact 10)
