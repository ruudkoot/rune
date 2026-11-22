-- Report 4.5.5, Rule 2 and 4.3.4: with n unused nothing fixes its type, and it has no default.
module Main (main) where

main :: IO ()
main = print (let [(n, s)] = reads "1 x" in s)
