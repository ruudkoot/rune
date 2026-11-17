-- The default taken away again: I, unedited, is taken again with the entry
-- made at step 1, against a class with no default, not the one made at
-- step 2, whose dictionary names C's default (build-cache-issues.md, issue 25).
module C where

class Describe a where
  describe :: a -> String
  name :: a -> String
