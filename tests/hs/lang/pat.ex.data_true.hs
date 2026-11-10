-- Report 3.17.2: data D = D !Bool: (\ (D True) -> True) bottom is bottom.
module Main (main) where

data D = D !Bool

main :: IO ()
main = print ((\(D True) -> True) undefined)
