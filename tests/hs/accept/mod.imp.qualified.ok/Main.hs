-- rows: mod.imp.unqualified mod.imp.qualifier mod.imp.qualifier.reexport mod.alias.qualifier mod.alias.unqualified mod.qual.import mod.qual.swap
-- Report 5.3.2, 5.3.3, 5.5.1: the qualified name of a qualified import, both names of an unqualified one, the module's name or
-- its alias as qualifier, and the importing module's qualifier for an entity it re-exports.
module Main (main) where

import qualified A
import N
import qualified N as Q
import B
import D as Dl (d)

main :: IO ()
main = print ((A.x, x, N.x, Q.y), (B.d, Dl.d, d))
