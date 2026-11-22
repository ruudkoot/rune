-- Report 4.1.3: the context mentions only type variables of the type: not Eq b => a -> a.
module Main (main) where

f :: Eq b => a -> a
f x = x

main :: IO ()
main = return ()
