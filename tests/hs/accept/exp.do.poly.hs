-- Report 3.14: a let in do is polymorphic.
module Main (main) where

m :: IO (Int, Char)
m = do { let { f x = x }; return (f 1, f 'a') }

main :: IO ()
main = return ()
