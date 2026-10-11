(* splitBaseExt and joinBaseExt of fix.diff, copied into a standalone program
   on top of OS.Path's splitDirFile, with the Unix checkArc. Every path of up
   to 7 characters from "a", ".", "/" and NUL is checked:
   - joinBaseExt (splitBaseExt p) = p, as the specification asks;
   - where p has no "//", which the old functions lose, both functions agree
     with OS.Path's, exceptions included.
   Run: sml fix-check.sml *)
structure SS = Substring
fun checkArc arc =
      if CharVector.all (fn c => c <> #"/" andalso c <> #"\000") arc then arc
      else raise OS.Path.InvalidArc
val splitDirFile = OS.Path.splitDirFile

    fun splitBaseExt p = let
	  val {file, ...} = splitDirFile p
	  val (file', ext') = SS.splitr (fn c => c <> #".") (SS.full file)
	  val fileLen = SS.size file'
	  in
	    if (fileLen <= 1) orelse (SS.isEmpty ext')
	      then (ignore (checkArc file); {base = p, ext = NONE})
	      else (
		ignore (checkArc (SS.string(SS.trimr 1 file')));
		{ base = SS.string(SS.trimr (SS.size ext' + 1) (SS.full p)),
		  ext = SOME(SS.string ext')
		})
	  end
    fun joinBaseExt {base, ext=NONE} = base
      | joinBaseExt {base, ext=SOME ""} = base
      | joinBaseExt {base, ext=SOME ext} = let
	  val {file, ...} = splitDirFile base
	  in
	    ignore (checkArc (String.concat[file, ".", ext]));
	    String.concat[base, ".", ext]
	  end

fun paths 0 = [""]
  | paths n = "" :: List.concat (map (fn p => map (fn c => c ^ p) ["a", ".", "/", "\000"]) (paths (n - 1)))
val all = ListMergeSort.uniqueSort String.compare (paths 7)
fun outcome f x = (SOME (f x) handle OS.Path.InvalidArc => NONE | OS.Path.Path => NONE)
val noDouble = List.filter (fn p => not (String.isSubstring "//" p)) all
val identity = List.filter (fn p => (joinBaseExt (splitBaseExt p) <> p) handle OS.Path.InvalidArc => false) all
val splitDiffer = List.filter (fn p => outcome splitBaseExt p <> outcome OS.Path.splitBaseExt p) noDouble
val exts = [NONE, SOME "", SOME "b", SOME "b.c", SOME "/", SOME "\000"]
val joinDiffer = List.filter (fn (b, e) => outcome joinBaseExt {base = b, ext = e} <> outcome OS.Path.joinBaseExt {base = b, ext = e})
                   (List.concat (map (fn b => map (fn e => (b, e)) exts) noDouble))
val () = print (concat [Int.toString (length all), " paths: joinBaseExt (splitBaseExt p) <> p for ", Int.toString (length identity), "\n",
                        Int.toString (length noDouble), " paths without \"//\": splitBaseExt differs from OS.Path's for ",
                        Int.toString (length splitDiffer), ", joinBaseExt (with 6 extensions) for ", Int.toString (length joinDiffer), "\n"])
val () = List.app (fn p => print ("base " ^ p ^ " = " ^ #base (splitBaseExt p) ^ "\n")) ["//", "a//b", "a//c.d", "//c.d"]
val () = OS.Process.exit OS.Process.success
