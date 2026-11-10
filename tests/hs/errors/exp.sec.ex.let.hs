-- Report 3.5: (let n = 10 in n +) is invalid, by the let/lambda meta-rule (the Report's example).
module Main (main) where

main :: IO ()
main = print ((let n = 10 in n +) 1)
