module B (k, p, q) where
import A (h)

k :: Int -> Int
k n = if n > 1 then h else n

p :: Eq a => a -> Bool
p x = x == x || q True

q :: Ord a => a -> Bool
q y = y < y || p y
