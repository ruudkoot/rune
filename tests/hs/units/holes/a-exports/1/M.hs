-- What Main imports moves: an entity added or removed that Main does not
-- name stands, one it names or that clashes with its own does not
-- (build-cache-issues.md, issue 37's A).
module M (f) where

f :: Int
f = 1
