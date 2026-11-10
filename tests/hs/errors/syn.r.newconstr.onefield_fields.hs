-- Report 9.5: newconstr -> con { var :: type }: one field, so not { a, b :: Int }.
module Main (main) where

newtype N = N { a, b :: Int }

main :: IO ()
main = return ()
