-- rows: R21
-- Report 4.5.2: signatures of a group's variables have contexts identical up to renaming (R21(b): rhc follows
-- the text, D32, though no oracle refuses it).
module Main (main) where

f :: Eq a => a -> Bool
f x = x == x || g x

g :: Ord a => a -> Bool
g y = y < y || f y

main :: IO ()
main = return ()
