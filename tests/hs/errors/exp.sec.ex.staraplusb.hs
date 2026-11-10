-- rows: exp.sec.rule.right
-- Report 3.5: "(op e) is legal if and only if (x op e) parses in the same way as (x op (e))": (*a+b) is
-- syntactically invalid (the Report's example).
module Main (main) where

main :: IO ()
main = print ((*a+b) 1)
  where
    a = 2 :: Int
    b = 3
