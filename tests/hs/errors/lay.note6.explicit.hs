-- Report 9.3, Note 6: "it is an error to be within a non-layout context at the end of the input".
module Main (main) where

main :: IO ()
main = print (let { x = 1