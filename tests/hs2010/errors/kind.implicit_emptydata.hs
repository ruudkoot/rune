-- Report 4.1.1: kinds are implicit and no part of the syntax: not data T (f :: * -> *) = C. In 2010 `data T` is an
-- empty data declaration (4.2.1), so the refusal comes at the `(` after it, where 98's comes inside the declaration
-- (tests/hs/errors/kind.implicit, which tests/hs2010/unshared.tsv keeps 98's).
module Main (main) where

data T (f :: * -> *) = C

main :: IO ()
main = return ()
