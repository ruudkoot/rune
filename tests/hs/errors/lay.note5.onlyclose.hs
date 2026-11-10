-- Report 9.3, Note 5: where } is no valid continuation either, the program is simply in error: `let x = in y`.
module Main (main) where

main :: IO ()
main = print (let x = in x)
