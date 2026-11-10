-- rows: R10
-- Report 3.5: (\x -> x +) is invalid by the same meta-rule: the lambda takes the +, and its body is no
-- expression (R10: sections checked after resolution).
module Main (main) where

main :: IO ()
main = print ((\x -> x +) 1 2)
