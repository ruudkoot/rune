-- Report 9.5: newconstr -> con atype | con { var :: type }: one field, so not N Int Int.
module Main (main) where

newtype N = N Int Int

main :: IO ()
main = return ()
