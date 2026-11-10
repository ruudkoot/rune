-- rows: R69
-- Report 4.1.2: no infix type constructor but (->): not data a `T` b = C.
module Main (main) where

data a `T` b = C

main :: IO ()
main = return ()
