-- Report 4.4.2, Table 4.1: `notElem` is infix 4, so two of it do not chain.
module Main (main) where

main :: IO ()
main = print (1 `notElem` [1] `notElem` [True])
