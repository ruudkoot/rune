-- Report 9.5: fexp -> [fexp] aexp: an argument is an aexp, so no unparenthesised lambda.
module Main (main) where

f :: (Int -> Int) -> Int
f g = g 1

main :: IO ()
main = print (f \x -> x)
