-- Report 4.1.2: there is no syntax for universal quantification: not forall a. a -> a.
module Main (main) where

f :: forall a. a -> a
f x = x

main :: IO ()
main = return ()
