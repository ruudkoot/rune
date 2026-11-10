-- rows: lay.col.tabalign
-- Report 9.3: "Tab stops are 8 characters apart", and "a tab character causes the insertion of enough spaces to align
-- the current position with the next tab stop": below a tab, eight spaces, and three spaces and a tab all
-- give column 9, one block.
module Main (main) where

main :: IO ()
main = print (a + b + c)
  where
	a = 1 :: Int
        b = 2
   	c = 3
