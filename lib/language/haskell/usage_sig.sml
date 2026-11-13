(* What a compile of a unit reads of the units it imports (the haskell98
   roadmap's M21, E13's obligations H1, H2, H7 and H9), noted where the
   renamer, the checker and the translations read it, so that a store's
   entry of the unit is used only where each read gives now what it gave
   then. A read is noted found or not: a name a module looks up and does
   not find is read too, since an import that comes to export it changes
   the module (5.5.2). The note is a no-op until a driver sets it (rhc's,
   src/rhc/iface.sml).

   Area: Languages *)
signature HS_USAGE =
sig
  (* A read. Spaces are `"v"` for a value and `"t"` for a type or class,
     and entities, classes and type constructors are by their keys
     (HsModules.key). *)
  datatype read =
      Name of {within : string, space : string, qual : string, name : string}
      (* a name looked up in the scope of the module of identity `within`,
         by the renamer or by its export list, qualified by `qual` or not
         (`""`), found or not (H1) *)
    | Item of {from : string, space : string, name : string}
      (* an item of an import list, a name of what the module of identity
         `from` exports (H1) *)
    | Exports of string
      (* every export of the module of that identity, as `module M` in an
         export list reads them (H7) *)
    | Instance of {cls : string, tycon : string}
      (* the instance of a class at a type constructor, looked up by the
         checker or by deriving's fixpoint, found or not (H2) *)
    | Standard of {space : string, name : string}
      (* what the Prelude exports under a name the translations of the
         Report name, `Bool` or `>>=` (H9) *)
    | Entity of string
      (* an entity the translations name by its key, a program unable to
         shadow it, as Ratio's % (H9) *)

  (* `setNote f` makes `f` the recorder, called with each read as it is
     made, and is the recorder before it: until a driver sets one, a no-op. *)
  val setNote : (read -> unit) -> (read -> unit)

  (* `read r` notes `r`. *)
  val read : read -> unit

  (* `key r` is `r` as one line of text, its fields apart by spaces, the
     name of a store's usage.

     Example: `key (Exports "M") = "exports M"` *)
  val key : read -> string

  (* `fromKey s` is the read whose key is `s`, NONE for none. *)
  val fromKey : string -> read option
end
