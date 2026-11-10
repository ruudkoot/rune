-- Report 2.6: escape -> \ ( ... | o octal | x hexadecimal ): `o` in lower case only.
module Main (main) where

c :: Char
c = '\O17'

main :: IO ()
main = return ()
