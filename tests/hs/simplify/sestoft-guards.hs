-- Guards in order, falling through to the next clause (3.17.2, 3.13): a
-- guard is evaluated only once its clause's patterns have matched and the
-- guards before it have failed, so q's second guard, a division by zero
-- where x is 0, is never reached for x = 0.
-- sestoft: as A
module Main where

p :: Int -> [Int] -> Int
p n (x:_) | n > 0 = x
p 0 _ = 100
p n (_:y:_) | n < 0 && y > 0 = y
            | n < 0 = negate y
p n xs | null xs = 0
       | otherwise = length xs + n

q :: Int -> Int -> Int
q x y | x == 0 = 0
      | y `div` x > 1 = 1
      | otherwise = 2

r :: Maybe Int -> Int
r (Just n) | n > 5 = n
r Nothing = 0
r (Just n) | n > 2 = n * 10
r _ = -1

main :: IO ()
main = do
  print (p 3 [7, 8], p 0 [1], p (-1) [1, 5], p (-1) [1, -5], p (-2) [4], p 5 [])
  print (q 0 5, q 2 9, q 3 1)
  print (r (Just 9), r (Just 3), r (Just 1), r Nothing)
