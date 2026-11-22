-- rows: exp.sec.rule.left
-- Report 3.5: "(e op) is legal if and only if (e op x) parses in the same way as ((e) op x)": not (a ^ b ^),
-- ^ being right associative.
module Main (main) where

main :: IO ()
main = print ((2 ^ 3 ^) 1)
