-- Report 1.4: types and classes share a namespace: data T = A with class T a is refused.
module Main (main) where

data T = A

class T a

main :: IO ()
main = return ()
