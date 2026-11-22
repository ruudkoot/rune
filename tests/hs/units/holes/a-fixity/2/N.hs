-- An operator's fixity, which M re-exports with it (build-cache-issues.md,
-- issue 37's A: the scope the same, the entity's fingerprint not).
module N ((+++)) where

infixl 5 +++

(+++) :: Int -> Int -> Int
a +++ b = a - b
