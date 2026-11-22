-- rows: R16
-- Report 3.15.3: an update may change the type of a field it names, as its translation by case does (R16).
module Main (main) where

data T a = C {x :: a, y :: Int}

v :: T Char
v = (C 1 2) {x = 'a'}

main :: IO ()
main = return ()
