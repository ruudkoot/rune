-- Report 9.5, with erratum Sept 2004: export -> qtycls [(..) | ( var1 , ... , varn )]: a class's methods are
-- named unqualified in an export.
module Main (main, Eq((Prelude.==))) where

main :: IO ()
main = return ()
