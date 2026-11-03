(* The virtual functor's other form, a plugin: Table is the functor that
   the unit table.rbu exports, loaded when the program reaches this
   declaration (docs/units.md, Dynamic modules). Either implementation is
   one, compiled apart from the program:

     rune --build plugin.build --emit-units plugin -o plugin.rbc
     cp plugin/units/...-tree.rbu table.rbu      (the unit of tree.sml)
     rune --build dynamic.build -o dynamic.rbc
     runevm dynamic.rbc *)
functor Table = _dynamic "table.rbu" (K : KEY) : TABLE where type key = K.t
