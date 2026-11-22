-- Report 4.2.1, 5.8: the export's form of a datatype's name sets its constructors' visibility: T
-- exported abstract, so C is not in scope where it is imported.
module Main (main) where

import Abstract

main :: IO ()
main = case mk of C _ -> return ()
