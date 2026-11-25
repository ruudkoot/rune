module Main (main) where
import A

fact :: Integer -> Integer
fact 0 = 1
fact (n+1) = (n+1) * fact n

main :: IO ()
main = print (f 'c', g (1 :: Int), fact 5)
