-- Report 5.4: a module whose only purpose is instances has an empty export list: the Report's MyInstances.
module Main (main) where

import MyInstances

main :: IO ()
main = print id
