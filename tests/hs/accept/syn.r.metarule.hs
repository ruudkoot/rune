-- rows: syn.r.metarule.cond syn.r.metarule.let syn.r.metarule.lambda
-- Report 9.1: "the grammar is ambiguous regarding the extent of lambda abstractions, let expressions, and conditionals.
-- The ambiguity is resolved by the meta-rule that each of these constructs extends as far to the right as
-- possible": the + 1 below is in the else, the let and the lambda.
module Main (main) where

main :: IO ()
main = print (if False then 0 else 1 + 1, let x = 1 in x + 1, (\x -> x + 1) 1 :: Int)
