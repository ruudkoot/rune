-- A type whose Show instance is elsewhere (build-cache-issues.md, issue
-- 37's A: what an instance read gives is not of the scope).
module T (T(..)) where

data T = T
