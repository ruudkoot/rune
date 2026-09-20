(* Boxes.

   Area: Tests *)
signature BOX =
sig
  (* What is in a box. *)
  type elem

  (* A box; there is a value of this name too. *)
  type box

  (* A box and a lid. *)
  type 'a lidded

  (* The side a box opens at. *)
  datatype side = Top | Front

  (* `box x` is a box with `x` in it. *)
  val box : elem -> box

  (* The labels of boxes. *)
  structure Label :
  sig
    (* A label. *)
    type label

    (* The label of nothing. *)
    val blank : label
  end
end

functor RuneBoxFn (type elem) =
struct
  type elem = elem
  type box = elem list
  type 'a lidded = 'a * bool
  datatype side = Top | Front
  fun box x = [x]
  fun full (b : box) = case b of [] => false | _ => true
  structure Label = struct type label = string val blank = "" val glue = "-" end
end

(* Implements: BOX where type elem = int *)
structure Box = RuneBoxFn (type elem = int)

(* Implements: BOX where type elem = int *)
structure Crate = Box

(* Implements: BOX where type elem = string *)
structure Chest =
struct
  type elem = string
  type box = Crate.Label.label
  type 'a lidded = 'a Box.lidded
  datatype side = datatype Box.side
  fun box (x : elem) : box = x
  val spare = ""
  structure Label = struct type label = box val blank = "" end
end
