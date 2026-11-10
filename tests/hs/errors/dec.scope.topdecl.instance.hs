-- Report 4: an instance declaration stands only at the top level: not in a let.
module Main (main) where

x :: Int
x = let instance Eq (a -> b) in 1

main :: IO ()
main = return ()
