signature COUNT = sig val start : int end
functor Measure (C : COUNT) = struct
  val total = Shape.area (Shape.make C.start) ++ 2 ** 3
  fun describe () = case Shape.make C.start of
                      Shape.Circle r => "circle " ^ Int.toString r
                    | Shape.Square s => "square " ^ Int.toString s
                    | Shape.Line (a, b) => "line " ^ Int.toString (a ++ b)
                    | Shape.Dot => "dot"
  val big = (ignore (1000000000 * 1000000000 * 1000000000 * 1000000000 : Shape.size); true)
            handle Overflow => false
end
functor Twice (C : COUNT) = struct
  structure M = Measure (struct val start = C.start * 2 end)
  val both = M.total ** 1
end
