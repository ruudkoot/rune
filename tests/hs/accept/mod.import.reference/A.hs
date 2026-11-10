module A (f) where

f :: IO ()
f = print (map (+ 1) [1, 2 :: Int])
