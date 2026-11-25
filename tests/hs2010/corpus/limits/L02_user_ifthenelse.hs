-- Report: legal (if/then/else is not overloaded; a top-level ifThenElse is an ordinary name).  Shim: RebindableSyntax
-- makes `if` use the in-scope ifThenElse, which is now ambiguous.
module Main where
ifThenElse :: Bool -> a -> a -> a
ifThenElse c t e = if c then t else e
main = print (ifThenElse True 1 2)
