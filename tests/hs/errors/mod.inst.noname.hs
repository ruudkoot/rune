-- Report 5.4: "Instance declarations cannot be explicitly named on import or export lists": no item spells one.
module Main (main, instance Show Int) where

main :: IO ()
main = return ()
