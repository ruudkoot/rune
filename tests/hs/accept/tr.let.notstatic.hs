-- Report 3.12: let f x = x in (f 1, f 'a') is accepted, though its translation by case would not be.
module Main (main) where

p :: (Int, Char)
p = let f x = x in (f 1, f 'a')

main :: IO ()
main = return ()
