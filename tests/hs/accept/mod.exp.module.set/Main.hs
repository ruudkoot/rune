-- rows: mod.exp.module.queue mod.exp.module.self mod.exp.module.mod1 mod.exp.module.anyimport mod.exp.module.empty
-- Report 5.2: module M exports what is in scope as both e and M.e: the Report's Queue over Stack, Mod1 exporting itself
-- and Mod2, a module imported qualified (an empty set), and one imported with () (empty too).
module Main (main) where

import Queue
import Mod1
import X

main :: IO ()
main = print (push 1 empty, enqueue 2, m1, m2)
