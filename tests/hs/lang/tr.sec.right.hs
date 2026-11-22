-- rows: tr.sec.left tr.sec.fresh tr.sec.whnf R11
-- Report 3.5: (op e) is \x -> x op e and (e op) is \x -> e op x, x not free in e; a section is a lambda, so a value.
module Main (main) where

main :: IO ()
main = do
  let x = 10 :: Int
  print (map (x -) [1, 2], map (`div` x) [20, 30])
  print (map (\y -> x - y) [1, 2], map (\y -> y `div` x) [20, 30])
  print (seq ((+ undefined) :: Int -> Int) (), seq ((undefined +) :: Int -> Int) ())
