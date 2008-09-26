let (~%) = Printf.sprintf
let p = print_string

module DummyPrinter = struct
    type t = int

    let create ~writer = 0

    let strstat s = (~% "[%d:%d]" s.Signatures.s_line s.Signatures.s_char)
    let head = "####"
    
    let handle_comment_line t location line =
        p (~% "%s%s[comment] \"%s\"\n" head (strstat location) line)
    let handle_text t location line =
        p (~% "%s%s[text] \"%s\"\n" head (strstat location) line)

    let start_command t location name args =
        p (~% "%s%s[start %s(%s)]\n" head (strstat location)
            name (String.concat ", " args))

    let stop_command t location = 
        p (~% "%s%s[stop]\n" head (strstat location))
        
    let terminate t location = 
        p (~% "%s%s[This is the end...]\n" head (strstat location))

    let handle_verbatim_line t location line =
        p (~% "%s%s[verbatim] %s\n" head (strstat location) line)

    let enter_verbatim t location args = ()
    let exit_verbatim t location = ()

    let dummy_writer = {
        Signatures.w_write = (fun s -> ());
        Signatures.w_warn = (fun s -> ());
        Signatures.w_error = (fun s -> ());
    }

end
module Options = struct

    (* let arg_set ref v = Arg.Unit (fun () -> ref := v) *)

    type output_format = [ `HTML | `LaTeX ]
    let output_format = ref (`HTML:output_format)
    let input_stream = ref stdin
    let output_stream = ref stdout
    let debug = ref false
    let header_footer = ref false
    let stylesheet_link = ref None

    let options = Arg.align [
        ("-html", Arg.Unit (fun () -> output_format := `HTML),
            ~% " Output HTML format (default)");
        ("-latex", Arg.Unit (fun () -> output_format := `LaTeX),
            ~% " Output LaTeX format");
        ("-debug", Arg.Set debug, " Debug mode");
        ("-doc", Arg.Set header_footer, "output a complete document");
        (
            "-i",
            Arg.String (fun s -> input_stream := open_in s), 
            "<file> input file (default is standard input)"
        );
        (
            "-o",
            Arg.String (fun s -> output_stream := open_out s), 
            "<file> output file (default is standard output)"
        );
        (
            "-link-stylesheet",
            Arg.String (fun s -> stylesheet_link := Some s),
            "<url> link to a stylesheet (CSS for XHTML), needs -doc"
        );

    ]
    let short_usage =
        ~% "usage: %s [-i file] [-o file] [-help]" Sys.argv.(0)
    let anon_fun s =
        prerr_string (~% "Warning argument %s is ignored\n" s)

    let get () =
        Arg.parse options anon_fun short_usage;
        (!output_format, !debug, !input_stream, !output_stream)


end

let read_line_opt i () = try Some (input_line i) with e -> None


let () = (
    let to_do, dbg, i, o = Options.get () in
    Sys.catch_break true;
    at_exit (fun () -> 
        close_in i;
        flush o;
        close_out o;
    );
    if dbg then (
        let module DummyTransformer = Transformer.Make(DummyPrinter) in
        let t =
            DummyTransformer.create
                ~writer:DummyPrinter.dummy_writer ~read:(read_line_opt i)
        in
        DummyTransformer.do_transformation t;
        p (~% "DEBUG Done;\n");
    ) else (
        let module HtmlTransformer = Transformer.Make(HtmlPrinter) in
        let write = output_string o in
        let writer =
            let warn = prerr_string in
            let error = prerr_string in
            Signatures.make_writer ~write ~warn ~error in
        let read = read_line_opt i in
        begin match to_do with
        | `HTML ->
                let t = HtmlTransformer.create ~writer ~read in
                if !Options.header_footer then
                    write (HtmlPrinter.header
                    ~comment:"Generated with BraceTax" ()
                    ?stylesheet_link:!Options.stylesheet_link
                    );
                    HtmlTransformer.do_transformation t;
                    if !Options.header_footer then
                        write (HtmlPrinter.footer ());
        | `LaTeX ->
                let module LatexTransformer = Transformer.Make(LatexPrinter) in
                let t = LatexTransformer.create ~writer ~read in
                ignore t;
        end;
    );
    (* close_in i; *)
    (* close_out o; *)
)

