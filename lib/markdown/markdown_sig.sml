(* Markdown: CommonMark's (0.31.2) blocks and inlines, with GitHub's
   tables, parsed into a tree; written back as the HTML of CommonMark's
   reference implementation, or laid out as a document of `Pretty` whose
   annotations say what each piece is, for a terminal or plain text.

   It reads what runedoc writes -- headings, paragraphs, fenced code,
   tables, lists, links, emphasis, code spans, entities and the HTML of
   its interface blocks -- and the rest of CommonMark well enough that
   tests/lib/markdown checks it on CommonMark's own examples for those
   constructs.

   Area: Text *)
signature MARKDOWN =
sig
  (* Inline content: text, code spans, emphasis, links and images, raw
     HTML, and the breaks between lines. *)
  datatype inline =
      Text of string
    | Code of string
    | Emphasis of inline list
    | Strong of inline list
    | Link of {target : string, title : string option, text : inline list}
    | Image of {source : string, title : string option, alt : inline list}
    | Html of string
    | SoftBreak
    | HardBreak

  (* How a table's column is aligned. *)
  datatype alignment = Default | Left | Center | Right

  (* A block. A list is tight when no blank line separates its items or
     the blocks of one; its paragraphs are then written without `<p>`. *)
  datatype block =
      Heading of int * inline list
    | Paragraph of inline list
    | CodeBlock of {info : string, text : string}
    | HtmlBlock of string
    | Quote of block list
    | List of {ordered : bool, start : int, tight : bool, items : block list list}
    | Table of {align : alignment list, header : inline list list, rows : inline list list list}
    | Rule

  (* `parse s` is the blocks of the Markdown text `s`.

     Example: `parse "# A *b*" = [Heading (1, [Text "A ", Emphasis [Text "b"]])]` *)
  val parse : string -> block list

  (* `toHtml bs` is the blocks as HTML, as CommonMark's reference
     implementation writes it.

     Example: `toHtml (parse "a *b*") = "<p>a <em>b</em></p>\n"` *)
  val toHtml : block list -> string

  (* What a piece of a laid-out document is, for its style.

     A heading of a level, code, emphasis, strong emphasis, a link to a
     target, a quote, a list's marker, or a table's rule. *)
  datatype role = Head of int | Mono | Italic | Bold | Anchor of string | Quoted | Marker | Ruler

  (* `toDoc bs` is the blocks as a document, annotated with their roles.

     Paragraphs are filled to the width they are laid out at, code is as it
     is, tables are in columns, lists have their markers, and a blank line
     is between blocks. *)
  val toDoc : block list -> role Pretty.doc

  (* `toText w bs` is the blocks as plain text at width `w`.

     Example: `toText 80 (parse "# Title\n\nSome *text*.") = "Title\n\nSome text."` *)
  val toText : int -> block list -> string
end
