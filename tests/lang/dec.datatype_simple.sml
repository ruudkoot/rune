datatype color = Red | Green | Blue
datatype shape = Circle of real | Rect of real * real | Point
fun name Red = "red" | name Green = "green" | name Blue = "blue"
fun area (Circle r) = 3.0 * r * r
  | area (Rect (w, h)) = w * h
  | area Point = 0.0
val () = print (name Red ^ name Blue ^ " " ^ Real.toString (area (Rect (2.0, 3.5))) ^ " " ^ Real.toString (area (Circle 1.0)) ^ " " ^ Real.toString (area Point) ^ "\n")
val () = print (Bool.toString (Red = Red) ^ Bool.toString (Red = Green) ^ Bool.toString (Circle 1.0 = Circle 1.0) ^ "\n")
