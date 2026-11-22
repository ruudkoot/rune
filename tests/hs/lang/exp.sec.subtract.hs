-- rows: exp.sec.plusneg exp.sec.partial exp.sec.neg
-- Report 3.5: (subtract e) and (+ (- e)) stand for the section (- e) cannot be, which is negation; sections partially
-- apply an operator.
module Main (main) where

main :: IO ()
main = do
  print (subtract 1 3 :: Int, (+ (- 1)) 3 :: Int)
  print (map (2 ^) [1, 2, 3 :: Int] :: [Int], map (^ 2) [1, 2, 3] :: [Int])
  print ((- 1) + 0 :: Int)
