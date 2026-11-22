-- HsLint's second inference: a restricted group whose members' types differ keeps its constrained
-- variable open until the module is inferred, where Typing Haskell in Haskell's split would default
-- it at once, so a later use fixes it (the roadmap's D32 and R20; Report 4.5.5, Rule 2).
module Main (main) where

a = fst (1, b)
b = snd (a, 'c')
c = a + (1.5 :: Double)

main :: IO ()
main = print (a, b, c)
