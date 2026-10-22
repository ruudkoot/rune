(* Compatibility for LAWS_PROGRAMS over generated ASCII program names.
   Matching is a bounded native regex adapter; selection policy and the
   complete selected-name set remain with the SML controller. *)
structure ProgramSelect =
struct
  open Sh
  exception Invalid of string
  fun filter {pattern, names, directory} =
    if pattern = "" then names else
      let
        val () = if CharVector.exists (fn c => c = #"\n" orelse c = #"\r") pattern
                 then raise Invalid "LAWS_PROGRAMS must be a single-line regular expression" else ()
        val () = mkdirs directory
        val input = directory ^ "/programs.txt"
        val output = directory ^ "/selected.txt"
        val errors = directory ^ "/regex.err"
        val () = write (input, String.concat (List.map (fn name => name ^ "\n") names))
        val status = Children.exec {addressSpace = SOME (128 * 1024 * 1024), cpuTime = SOME 5,
                                   fileSize = SOME (1024 * 1024), core = SOME 0} (fn e => e)
          {cmd = ["grep", "-P", "--", pattern], dir = SOME root, stdin = input, stdout = output, stderr = errors, timeout = 5}
        val () = if status = 0 orelse status = 1 then ()
                 else raise Invalid ("LAWS_PROGRAMS regex failed: " ^ firstNonEmpty errors)
        val selected = lines (read output)
        val () = if List.all (fn name => List.exists (fn original => name = original) names) selected then ()
                 else raise Invalid "regex adapter returned an unknown program"
      in selected end
end
