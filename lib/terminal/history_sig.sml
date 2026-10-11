(* The history of what was typed at a prompt, kept in a file that several
   sessions share.

   An entry is one accepted input, however many lines it has; in the file
   it is one line, with its newlines and backslashes escaped. Each entry
   is appended with one write, so that two sessions that add at once
   interleave entries and never lines, and a session reads at each prompt
   what the others have appended since it last looked. An entry the same
   as the one before it is not added again. The file is kept under twice
   the limit of entries by writing the last of them to a new file and
   renaming it over the old.

   Area: Terminals *)
signature HISTORY =
sig
  (* A history: its entries, and the file they are kept in, if any. *)
  type history

  (* `defaultFile ()` is where Rune's programs keep their history, or
     `NONE` when the environment names no place.

     It is `$XDG_STATE_HOME/rune/history`, `%LOCALAPPDATA%\rune\history`
     on Windows, or `~/.local/state/rune/history`, by the first of those
     variables that is set. *)
  val defaultFile : unit -> string option

  (* `load {file, limit}` is the history of `file`, its last `limit`
     entries; an empty one when the file does not exist yet, and one that
     is not kept when `file` is `NONE`. *)
  val load : {file : string option, limit : int} -> history

  (* `entries h` is the entries of `h`, the oldest first. *)
  val entries : history -> string vector

  (* `add (h, e)` adds the entry `e` to `h` and its file, after what the
     other sessions have added.

     It does nothing when `e` is empty or is the last entry. A file that
     cannot be written is left alone. *)
  val add : history * string -> unit

  (* `refresh h` reads what other sessions have appended to the file since
     `h` last read it. *)
  val refresh : history -> unit

  (* `escape e` is the entry `e` as a line of the file: a newline is `\n`,
     a carriage return `\r`, a backslash `\\`.

     Example: `escape "a\nb\\c" = "a\\nb\\\\c"` *)
  val escape : string -> string

  (* `unescape l` is the entry that the line `l` is.

     Law: `unescape (escape e) = e`

     Example: `unescape "a\\nb" = "a\nb"` *)
  val unescape : string -> string
end
