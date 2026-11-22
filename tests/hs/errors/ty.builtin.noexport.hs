-- Report 4.1.2: the built-in type constructors cannot be named in an export list: not (->).
module Main (main, (->)) where


main :: IO ()
main = return ()
