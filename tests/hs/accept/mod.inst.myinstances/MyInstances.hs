module MyInstances () where

instance Show (a -> b) where
  show f = "<<function>>"

instance Show (IO a) where
  show io = "<<IO action>>"
