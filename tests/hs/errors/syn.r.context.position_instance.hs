-- Report 9.5: topdecl -> instance [scontext =>] qtycls inst ...; scontext holds only qtycls tyvar: no Eq (f a)
-- in an instance's context.
module Main (main) where

class C a
instance Eq (f a) => C [f a]

main :: IO ()
main = return ()
