-- Report 3.7: : is built-in syntax and takes no fixity declaration.
module Main (main) where

infixl 3 :

main :: IO ()
main = return ()
