-- Report 4.5.3, 4.1.3: the type is Eq a => ..., and Eq [a] is no context of a signature.
module Main (main) where

f :: Eq [a] => [a] -> a -> Bool
f xs y = xs == [y]

main :: IO ()
main = return ()
