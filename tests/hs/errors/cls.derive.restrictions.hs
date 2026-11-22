-- rows: R74
-- Report 4.3.3, 4.5.3: a derived instance has a simple context, as a user's does.
module Main (main) where

data Apply a b = App (a b) deriving Show

main :: IO ()
main = return ()
