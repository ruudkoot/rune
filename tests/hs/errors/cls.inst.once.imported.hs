-- Report 4.3.2, 5.6.2: nor again beside an imported instance: instance Show Char.
module Main (main) where

instance Show Char where
  show _ = "c"

main :: IO ()
main = return ()
