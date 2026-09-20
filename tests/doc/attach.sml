(* The signature's own comment: it stands directly above the declaration, and
   it is the first comment of the file.

   A second paragraph belongs to it as well. *)
signature ATTACH =
sig
  (* ---- Types ---- *)

  (* A comment above a specification documents it. *)
  type t

  (* Above a datatype: the datatype. *)
  datatype colour =
      Red                      (* after a constructor, on its line *)
    | Green of int             (* the bar of the next line does not matter *)
      (* on a line of its own inside a datatype: the next constructor *)
    | Blue of {depth : int,    (* after a field and its comma *)
               (* above a field *)
               alpha : real,
               name : string (* after the last field, before the brace *)}
    | Black (* after the last constructor: the constructor, not the datatype *)

  exception Failed of {why : string, (* why it failed *) code : int}  (* after the brace: the exception *)

  (* ---- Values ---- *)

  (* This paragraph stands for itself: a blank line follows it. It belongs to
     the section Values. *)

  (* Above the first of two. *)
  val first : t
  val second : t   (* after a value *)

  val third : t
  and fourth : t   (* after a description that follows `and` *)
  (* above an `and` *)
  and fifth : t

  val record : {x : int, (* the x *)
                y : int} -> t

  (* Above a substructure with a signature of its own. *)
  structure Inner :
  sig
    (* ---- Inside ---- *)

    (* Above a value of the substructure. *)
    val deep : t

    (* The last words of the substructure. *)
  end

  (* Above an include. *)
  include ORD

  (* At the end of the signature: prose as well. *)
end

(* Above a structure. *)
structure Attach =
struct
  (* ignored: structure bodies are not documented *)
  val x = 1  (* ignored too *)

  (* Above a substructure binding. *)
  structure Sub = struct end
end

(* This one is followed by a blank line and documents nothing. *)

(* Above a functor. *)
functor AttachFn (X : sig end) = struct end
