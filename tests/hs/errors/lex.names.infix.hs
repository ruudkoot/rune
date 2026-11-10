-- Report 2.4: "Variables and constructors have infix forms, the other four do not": no infix type constructor in a type.
module Main (main) where

f :: a :+: b -> a
f = undefined

main :: IO ()
main = return ()
