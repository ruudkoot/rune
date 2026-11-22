-- rows: exp.fix.left exp.fix.right exp.fix.differentprec exp.neg.prec exp.parse.fgapp exp.parse.negf
-- Report 3: fixities resolve an unparenthesised expression: declared ones change its value; - and ^ associate as
-- declared, + and * by precedence; prefix - has the precedence of binary -; f x + g y is (f x) + (g y).
module Main (main) where

infixr 6 -.

(-.) :: Int -> Int -> Int
a -. b = a - b

f, g :: Int -> Int
f x = x * 10
g y = y + 1

main :: IO ()
main = do
  print (10 -. 3 -. 2, 10 - 3 - 2)
  print (2 ^ 3 ^ 2 :: Int)
  print (2 + 3 * 4, 2 * 3 + 4 :: Int)
  print (- 2 `div` 3 :: Int, - 2 + 3 :: Int, - 3 ^ 2 :: Int)
  print (f 1 + g 2, - f 1 + 5)
