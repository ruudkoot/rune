-- Report 3.15.2: a construction names a field once.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

v :: T
v = C1 {f1 = 1, f1 = 2}

main :: IO ()
main = return ()
