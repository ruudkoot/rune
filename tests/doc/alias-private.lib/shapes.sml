(* Areas of shapes.

   Area: Tests *)
signature AREA =
sig
  (* `square s` is the area of a square whose side is `s`.

     Example: `square 3 = 9` *)
  val square : int -> int
end

(* The shapes, as the sources write them: the header does not export them. *)
structure ShapesImpl =
struct
  (* The areas. *)
  structure Area : AREA =
  struct
    fun square s = s * s
  end
  (* The sides of a square. *)
  val sides = 4
end

(* The shapes, under the name a program uses. *)
structure Shapes = ShapesImpl

(* The figures, whose areas are the shapes'. *)
structure Figures =
struct
  structure Area = ShapesImpl.Area
  val corners = ShapesImpl.sides
end
