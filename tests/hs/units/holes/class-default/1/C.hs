-- A class whose method `describe` has no default (build-cache-issues.md, issue 25).
module C where

class Describe a where
  describe :: a -> String
  name :: a -> String
