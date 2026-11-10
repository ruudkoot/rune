-- HsLint's comparison (the roadmap's M16, D54): this program's dump, read back as a record's
-- claims, holds; each fault of RHC_HSLINT_FAULT reads the first claim its rule checks corrupted,
-- which that rule refuses: a kind, a derived context, a type, Rule 1, a signature, a default's
-- classes, Rule 2's default at the module's end and a group's default.
module Main (main) where

data T a = T a deriving (Eq, Show)

n = 2
m = n + 1.5

size :: Int
size = 3

main :: IO ()
main = print (T 10 == T 20, m, size)
