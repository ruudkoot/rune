-- rows: R7
-- Report 2.4: varsym excludes reservedop, so `F.=` is no qvarsym: maximal munch reads `F`, then the varsym `.=`.
module Main (main) where

data T = F Int deriving Show

(.=) :: (Int -> T) -> Int -> T
f .= x = f x

main :: IO ()
main = print (F.=1)
