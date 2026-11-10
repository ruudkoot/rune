-- rows: dec.data.deriving.forms dec.data.infix.prec dec.data.infix.backquote dec.data.infix.strict dec.data.prefix.op dec.data.record.empty
-- Report 4.2.1: the deriving part is optional, and takes one class, or zero or more in parentheses, qualified or not;
-- constructor application binds tighter than an infix constructor; a conop may be backquoted, its operands
-- strict; a con may be a parenthesised consym; a record constructor may have no fields.
module Main (main) where

data A = A
data B = B deriving Eq
data Z = Z deriving ()
data Q = Q deriving (Eq, Prelude.Ord)
data T = Int :+ Maybe Int | Int `C` Int | !Int :* !Int | (:-) Int Int | R {} deriving Show

main :: IO ()
main = print (1 :+ Just 2, 1 `C` 2, (:-) 1 2, B == B, Q < Q)
