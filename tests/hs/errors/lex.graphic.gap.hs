-- rows: R5
-- Report 2.2: uniSmall is the lowercase letters and uniLarge the upper and titlecase ones, so U+4E2D, a letter with
-- no case (Lo), is in no class of graphic and begins no identifier (R5: rhc keeps the Report's classes in
-- identifiers, D38).
module Main (main) where

main :: IO ()
main = print 中
  where 中 = 1 :: Int
