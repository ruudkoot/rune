-- Report 3.13: "each alternative must have at least one body": not case x of { y where z = 1 }.
module Main (main) where

main :: IO ()
main = print (case 1 of { y where z = 1 })
