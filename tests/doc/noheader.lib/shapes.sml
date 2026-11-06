(* A helper that the header does not export.

   Area: Tests *)
signature HIDDEN =
sig
  (* Two. *)
  val two : int
end

structure Helper : HIDDEN = struct val two = 2 end

(* Areas of shapes.

   Area: Tests *)
signature AREA =
sig
  (* `square s` is the area of a square whose side is `s`.

     Example: `square 3 = 9` *)
  val square : int -> int
end

(* The shapes, under the name the sources give them. *)
structure RuneShapes =
struct
  (* The areas. *)
  structure Area : AREA =
  struct
    fun square s = s * s
  end
  val sides = Helper.two * Helper.two
end

(* The shapes, under the name a program uses. *)
structure Shapes = RuneShapes
