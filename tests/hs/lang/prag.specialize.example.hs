-- rows: prag.notlanguage
-- Report 11.2: the Report's factorial with its SPECIALIZE pragma: the result is the same with the pragma as without, which
-- is all a pragma may do.
module Main (main) where

factorial :: Num a => a -> a
factorial n = if n == 0 then 1 else n * factorial (n - 1)
{-# SPECIALIZE factorial :: Int -> Int, Integer -> Integer #-}

factorial2 :: Num a => a -> a
factorial2 n = if n == 0 then 1 else n * factorial2 (n - 1)

main :: IO ()
main = print (factorial (10 :: Int), factorial (25 :: Integer), factorial 25 == factorial2 (25 :: Integer))
