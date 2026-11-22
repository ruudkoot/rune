-- Report 3.15.3: an update names a field once.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

g :: T -> T
g r = r {f1 = 1, f1 = 2}

main :: IO ()
main = return ()
