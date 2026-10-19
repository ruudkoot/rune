(* David Hanley's nofib Mandel2 tree. Keep the original direction conditions,
   including scans beyond zero-height rectangles. *)
functor BenchMandelTwoFn (structure D : BENCH_SUSPEND
  structure P : sig val colour : int * int -> int end) =
struct
  datatype node = NS of node D.t * node D.t | EW of node D.t * node D.t | Leaf of int
  type tree = node D.t
  fun perimeter ((x1, y1), (x2, y2)) =
    if x1 = x2 andalso y1 = y2 then P.colour (x1, y1) else
    let val col1 = D.delay (fn () => P.colour (x1, y1))
        val col2 = D.delay (fn () => P.colour (x2, y1))
        val col3 = D.delay (fn () => P.colour (x2, y2))
        val col4 = D.delay (fn () => P.colour (x1, y2))
        val different = if D.force col1 = D.force col2 then
          if D.force col1 = D.force col3 then D.force col1 <> D.force col4 else true else true
        fun line (x, y) (dx, dy) =
          let val finished = if dx = 1 then x >= x2 else if dy = 1 then y <= y2
                             else if dx = ~1 then x <= x1 else y >= y1
          in if finished then true else if P.colour (x, y) <> D.force col1 then false
             else line (x + dx, y + dy) (dx, dy) end
    in if different then ~1
       else if line (x1 + 1, y1) (1, 0) andalso line (x2, y1 + 1) (0, 1)
               andalso line (x2 - 1, y2) (~1, 0) andalso line (x1, y2 - 1) (0, ~1)
       then D.force col1 else ~1 end
  fun build (p1 as (x1, y1)) (p2 as (x2, y2)) = D.delay (fn () =>
    let val colour = perimeter (p1, p2)
    in if colour <> ~1 then Leaf colour
       else if x2 - x1 >= y2 - y1 then
         let val middle = (x2 + x1) div 2
             val right = build (middle + 1, y1) p2
             val left = build p1 (middle, y2)
             val _ = D.force right
         in NS (left, right) end
       else
         let val middle = (y2 + y1) div 2
             val right = build (x1, middle + 1) p2
             val left = build p1 (x2, middle)
             val _ = D.force right
         in EW (left, right) end
    end)
  fun write width emit tree =
    let fun bounds (x1, y1, x2, y2) = String.concat
          [Int.toString x1, " ", Int.toString y1, " ", Int.toString x2, " ", Int.toString y2]
        fun walk (x1, y1, x2, y2) tree = case D.force tree of
            Leaf c => (emit ("L " ^ bounds (x1, y1, x2, y2) ^ " " ^ Int.toString c ^ "\n"); 1)
          | NS (left, right) =>
              let val _ = emit ("NS " ^ bounds (x1, y1, x2, y2) ^ "\n")
                  val middle = (x1 + x2) div 2
                  val a = walk (x1, y1, middle, y2) left
                  val b = walk (middle + 1, y1, x2, y2) right
              in 1 + a + b end
          | EW (left, right) =>
              let val _ = emit ("EW " ^ bounds (x1, y1, x2, y2) ^ "\n")
                  val middle = (y1 + y2) div 2
                  val a = walk (x1, y1, x2, middle) left
                  val b = walk (x1, middle + 1, x2, y2) right
              in 1 + a + b end
    in walk (0, 0, width, width div 2) tree end
end
