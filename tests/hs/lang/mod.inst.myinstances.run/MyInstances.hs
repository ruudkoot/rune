module MyInstances () where

instance Show (a -> b) where
  show _ = "<<function>>"

instance Show (IO a) where
  show _ = "<<IO action>>"
