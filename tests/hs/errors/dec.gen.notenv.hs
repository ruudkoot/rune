-- Report 4.5.2, 4.5.4: a variable of the environment is not quantified: the Report's g at Bool and Char.
module Main (main) where

f x = let g y z = ([x, y], z) in (g True, g 'c')

main :: IO ()
main = return ()
