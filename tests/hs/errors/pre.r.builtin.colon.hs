-- Report 8: (:) is built-in syntax and takes no fixity declaration.
module Main (main) where

infixr 5 :
main :: IO ()
main = return ()
