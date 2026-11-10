-- Report 2.4: ":" alone "is reserved solely for use as the Haskell list constructor; this makes its treatment uniform
-- with other parts of list syntax, such as "[]" and "[a,b]"": in an expression, a pattern and a section.
module Main (main) where

f :: [Int] -> [Int]
f (x : xs) = x : 0 : xs
f [] = [] ++ [1, 2]

main :: IO ()
main = print (f [3], (: []) 4, (5 :) [])
