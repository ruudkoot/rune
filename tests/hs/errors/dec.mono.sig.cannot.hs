-- Report 4.5.4: no signature expresses a monomorphic type variable.
module Main (main) where

f x = let { g :: a -> b -> ([a], b) ; g y z = ([x, y], z) } in g x True

main :: IO ()
main = return ()
