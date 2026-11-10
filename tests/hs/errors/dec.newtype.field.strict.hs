-- Report 4.2.3: newconstr -> con { var :: type }: no strictness flag.
module Main (main) where

newtype T = C { a :: !Int }

main :: IO ()
main = return ()
