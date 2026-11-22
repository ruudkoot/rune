-- Report 5.2: the unqualified names exported are distinct in their name space: the Report's invalid A.
module Main (main) where

import A2

main :: IO ()
main = return ()
