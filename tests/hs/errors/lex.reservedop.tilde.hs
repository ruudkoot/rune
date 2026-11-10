-- rows: R59
-- Report 2.4: reservedop -> .. | : | :: | = | \ | | | <- | -> | @ | ~ | =>: `~` is no operator to define.
module Main (main) where

(~) :: Int -> Int -> Int
(~) a b = a

main :: IO ()
main = return ()
