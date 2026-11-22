-- rows: R10
-- Report 3.5: (-5 *) is no section, since -5 * x parses as -(5 * x) (R10: sections checked after resolution).
module Main (main) where

main :: IO ()
main = print ((-5 *) 2)
