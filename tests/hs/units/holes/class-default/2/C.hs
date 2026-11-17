-- The class given a default of `describe`: I, unedited, is compiled again,
-- its dictionary made of the default (build-cache-issues.md, issue 25).
module C where

class Describe a where
  describe :: a -> String
  describe _ = "default"
  name :: a -> String
