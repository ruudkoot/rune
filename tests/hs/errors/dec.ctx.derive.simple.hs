-- rows: R74
-- Report 4.5.3: a derived instance's context is simple: Show (a b) is not.
module Main (main) where

data Apply a b = App (a b) deriving Show

main :: IO ()
main = return ()
