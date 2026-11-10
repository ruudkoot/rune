-- Report 2.4: reservedid includes _, so it is no variable in an expression.
module Main (main) where

main :: IO ()
main = print _
