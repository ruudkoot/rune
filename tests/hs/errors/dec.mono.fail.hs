-- Report 4.5.4: a monomorphic variable has one type at all its uses: g at Bool and Char.
module Main (main) where

f x = let g y z = ([x, y], z) in (g True, g 'c')

main :: IO ()
main = return ()
