-- Report 4.1.2: the built-in type constructors are not qualified: not Prelude.().
module Main (main) where

x :: Prelude.()
x = ()

main :: IO ()
main = return ()
