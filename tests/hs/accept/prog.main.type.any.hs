-- rows: prog.main.type.poly
-- Report 5: the t of IO t is any type, and a polymorphic IO a instantiates to it.
module Main (main) where

main :: IO Int
main = return 3

other :: IO a
other = ioError (userError "x")
