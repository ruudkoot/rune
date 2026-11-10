-- Report 3.5 and 9.5: "(op e) is legal if and only if (x op e) parses in the same way as (x op (e))", and
-- -5 * x is -(5 * x), so (-5 *) is no section; (-5 +) is (R10: sections checked after resolution).
module Main (main) where

main :: IO ()
main = print ((-5 *) 2)
