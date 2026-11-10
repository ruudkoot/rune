-- A local overloaded binding specialised with its function (Augustsson
-- 1993, section 5.4, fig 10): sum' stays overloaded inside a specialised
-- mySum unless the specialiser copies it too.
-- fuel: every lint holds and it prints the same whatever rewrite it stops after
module Main where

mySum :: Num a => [a] -> a
mySum l = sum' l 0
  where sum' [] a = a
        sum' (x:xs) a = sum' xs (a + x)

-- a local overloaded binding used at two types
twice :: (Show a) => a -> String
twice x = let f :: (Show b) => b -> String
              f y = show y ++ "!"
          in f x ++ f (length (f x))

-- a local overloaded binding of its own dictionary, recursive
countDown :: Integral a => a -> [a]
countDown n = go n
  where go k | k <= 0 = []
             | otherwise = k : go (k - 1)

main :: IO ()
main = do
  print (mySum [1 .. 1000 :: Int])
  print (mySum [1 .. 1000 :: Integer])
  print (mySum [0.5, 0.25, 0.125 :: Double])
  putStrLn (twice (42 :: Int))
  putStrLn (twice "hi")
  print (countDown (5 :: Int), countDown (3 :: Integer))
