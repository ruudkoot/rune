module A (f, g) where

f :: IO ()
f = putStrLn "A"

g :: Int -> Int
g x = x * 10
