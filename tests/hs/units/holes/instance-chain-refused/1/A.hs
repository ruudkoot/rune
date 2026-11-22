-- Show T is in scope here only through Mid's import of Orphan (5.4).
module A where

import T
import Mid

a :: String
a = show T
