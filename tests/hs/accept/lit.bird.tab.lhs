-- Report 9.4: the > is replaced by a space before layout, so a tab after it is measured from column 2 and
-- reaches column 9, as > and seven spaces do.

> module Main (main) where

> main :: IO ()
> main = print (a + b)
>   where
>	a = 1 :: Int
>       b = 2
