-- Show T's instance, on the chain from A by Mid's import.
module Orphan where

import T

instance Show T where
  show _ = "orphan"
