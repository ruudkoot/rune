-- Report 2.6: escape -> \ ( ... | o octal | x hexadecimal ): `x` in lower case only.
module Main (main) where

c :: Char
c = '\X41'

main :: IO ()
main = return ()
