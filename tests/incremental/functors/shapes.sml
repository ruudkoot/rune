structure Shape = struct
  datatype shape = Circle of int | Square of int | Line of int * int | Dot
  type size = int
  exception Bad of int
  fun area (Circle r) = 3 * r * r
    | area (Square s) = s * s
    | area (Line (a, b)) = a ++ b
    | area Dot = 0
  fun make n = if n > 10 then Circle n else if n > 5 then Square n else if n > 0 then Line (n, 1) else Dot
end
