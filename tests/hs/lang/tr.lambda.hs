-- rows: tr.lambda.fresh
-- Report 3.3: \p1 ... pn -> e is \x1 ... xn -> case (x1, ..., xn) of (p1, ..., pn) -> e, the xi new: they capture
-- nothing of e.
module Main (main) where

f1 :: Maybe Int -> [Int] -> Int
f1 = \(Just a) [b] -> a + b

f2 :: Maybe Int -> [Int] -> Int
f2 = \x1 x2 -> case (x1, x2) of (Just a, [b]) -> a + b

x1 :: Int
x1 = 100

g :: Int -> (Int, Int) -> Int
g = \x2 (y, _) -> x1 + x2 + y

main :: IO ()
main = do
  print (f1 (Just 1) [2], f2 (Just 1) [2])
  print (g 1 (2, undefined))
