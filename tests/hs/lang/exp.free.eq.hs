-- rows: exp.free.ge exp.free.minus
-- Report 3: free variables and constructors of the translations always refer to the Prelude's entities, whatever is
-- in scope: a literal pattern uses the Prelude's ==, and n+k its >= and -, not the module's, which abort.
module Main (main) where

import Prelude hiding ((==), (>=), (-))

(==) :: Int -> Int -> Bool
_ == _ = error "own =="

(>=) :: Int -> Int -> Bool
_ >= _ = error "own >="

(-) :: Int -> Int -> Int
_ - _ = error "own -"

f :: Int -> String
f 0 = "zero"
f _ = "other"

g :: Int -> Int
g (n + 1) = n
g _ = 100

main :: IO ()
main = print (f 0, f 1, g 5, g 0)
