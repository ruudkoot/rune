-- Mid no longer imports Orphan: in A, Read N is out of scope, and its
-- default is Integer. A, unedited, is compiled again.
module Mid where

mid :: Int
mid = 0
