module Main (main) where
import A
main :: IO ()
main = print (f 'c', g (1 :: Int), h)
