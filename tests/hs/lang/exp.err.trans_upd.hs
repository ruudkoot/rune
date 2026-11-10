-- rows: exp.field.upd.runtime
-- Report 3.1, 3.15.3: updating a field that the value's constructor lacks is an error at run time.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

main :: IO ()
main = print (f1 ((C1 1 2) {f3 = 'a'}))
