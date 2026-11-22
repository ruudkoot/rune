-- Report 3.14: a binding of do is monomorphic.
module Main (main) where

m :: IO (Int, Char)
m = do { f <- return id; return (f 1, f 'a') }

main :: IO ()
main = return ()
