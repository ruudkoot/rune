-- rows: syn.body.3 syn.r.body.emptydecls
-- Report 9.5: module -> body, the module Main (main) by 5.1; body -> { topdecls }, whose topdecl may be empty.
{ ; main :: IO () ; ; main = return () ; }
