-- Report 9.5: topdecl -> class [scontext =>] tycls tyvar ...; scontext holds only simpleclass -> qtycls tyvar:
-- no Eq [a] in a class's context.
module Main (main) where

class Eq [a] => C a

main :: IO ()
main = return ()
