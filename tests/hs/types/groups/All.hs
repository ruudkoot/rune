-- A declaration group is made by binding alone (4.5.1), a signature cutting nothing (R21(c)), and its implicitly
-- typed bindings are typed as one, monomorphic in the group (4.4.1; Typing Haskell in Haskell's conformant form,
-- 11.6.3). atom, expr and atomOrOp are one group through the signed expr, so atom's use in atomOrOp fixes atom's list
-- to [Char], where splitting the group's implicit bindings by their own dependencies would leave atom's list a type
-- variable: as nofib's parser's paAExpr (tests/hs/rhc-corpus.txt), where HsLint's inference and the checker parted.
module All () where

atom n = if n == 0 then (False, []) else (fst (expr (n - 1)), [])

expr :: Int -> (Bool, [Char])
expr n = atomOrOp n

atomOrOp n = if n > 5 then atom n else (True, "op")
