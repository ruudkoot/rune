-- HsLint's second inference: an ambiguous type variable whose classes include no numeric one is not
-- defaulted (Report 4.3.4, R22), and the program is refused, by the checker too.
module Main (main) where

main :: IO ()
main = putStrLn (show (read "1"))
