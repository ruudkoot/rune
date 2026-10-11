(* What a program shows beside what it prints: an output in several forms
   -- text, HTML, an image -- of which the front shows the best it can
   (docs/kernel.md).

   In a Jupyter notebook an output is the cell's display output, which a
   later `update` of the same id replaces; at the REPL's terminal, and in a
   program compiled by `rune`, its `text/plain` form is printed, or else its
   first.

   Area: The runtime

   Status: extension

   Deviation: `DISPLAY/not-in-the-specification`. The specification knows
   no front but a text stream; this signature is Rune's own.

   See also: `REPL` *)
signature DISPLAY =
sig
  (* The forms of an output, by MIME type: `("text/html", "<b>hi</b>")`,
     `("text/plain", "hi")`. *)
  type bundle = (string * string) list

  (* `display b` shows the output `b`. *)
  val display : bundle -> unit

  (* `displayAs (id, b)` shows `b` as the output named `id`, which `update`
     replaces. *)
  val displayAs : string * bundle -> unit

  (* `update (id, b)` replaces the output named `id` with `b`, where the
     front can; elsewhere it shows `b`. *)
  val update : string * bundle -> unit

  (* `clear wait` clears the outputs the cell has shown, at once or, with
     `wait`, when the next comes; nothing where the front cannot. *)
  val clear : bool -> unit
end
