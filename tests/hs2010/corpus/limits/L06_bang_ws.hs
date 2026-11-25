-- Report: ! is an ordinary operator; `f !x` defines (!).  GHC 9 lexes a prefix ! as a bang pattern (proposal 229).
module Main where
data T = T
(!) :: T -> Int -> Int
_ ! x = x
g :: T -> Int -> Int
g t !x = 0
main = print (T ! 3)
