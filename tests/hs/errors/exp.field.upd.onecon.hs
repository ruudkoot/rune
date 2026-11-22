-- Report 3.15.3: the Report's example: x {f2 = 1, f3 = 'x'} names fields of no one constructor.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

g :: T -> T
g x = x {f2 = 1, f3 = 'x'}

main :: IO ()
main = return ()
