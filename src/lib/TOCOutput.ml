let spr = Printf.sprintf

type inside = {
    mutable current: (int * string option) option;
    title_buffer: Buffer.t;
    mutable sections: (int * string option * string) list;
}

let store_opt me str () = (
    if me.current <> None then (
        Buffer.add_string me.title_buffer str;
    );
    ""
)
let store_opt_nonunit me str = (
    if me.current <> None then (
        Buffer.add_string me.title_buffer str;
    );
    ""
)
let start_section me level label = (
    me.current <- Some (level, match label with "" -> None | s -> Some s);
    ""
)
let stop_section me level label = (
    let lv, lb =
        match me.current with None -> failwith "Gni ??" | Some (a,b) -> (a,b) in
    me.sections <- (lv, lb, Buffer.contents me.title_buffer) :: me.sections;
    Buffer.reset me.title_buffer;
    me.current <- None;
    ""
)
let termination me () = (
    String.concat "" 
        (List.rev_map (fun (level, label, title) ->
            let l = match label with None -> "" | Some s -> s in
            (spr "{section %d %s|%s}\n" level l title)) me.sections)


)

let create () = (
    let me = {
        current = None;
        title_buffer = Buffer.create 42;
        sections = [] } in
    {
        GenericPrinter.

        start_text = (fun _ -> "");
        terminate = termination me;
        start_code = (fun _ -> "");
        code_line = (fun a -> "");
        stop_code = (fun _ -> "");

        line = store_opt_nonunit me;
        comment_line = (fun _ -> "");

        quotation_open = (fun style ->
            store_opt me (spr "{q %s|" style) ());
        quotation_close = (fun style ->
            store_opt me "}" ());

        start_italic = store_opt me "{i|";
        start_bold = store_opt me "{b|";
        start_type = store_opt me "{t|";
        start_sup = store_opt me "{sup|";
        start_sub = store_opt me "{sub|";
        stop_italic = store_opt me "}";
        stop_bold = store_opt me "}";
        stop_type = store_opt me "}";
        stop_sup = store_opt me "}";
        stop_sub = store_opt me "}";

        list_start = (fun _ -> "");
        list_first_item = (fun _ -> "");
        list_item = (fun _ -> "");
        list_stop = (fun _ -> "");

        section_start = start_section me;
        section_stop  = stop_section me;

        paragraph  = store_opt me "{p}";
        new_line  = store_opt me "{br}";
        non_break_space  = store_opt me "{~}";
        horizontal_ellipsis  = store_opt me "{...}";
        open_brace  = store_opt me "{{}";
        close_brace  = store_opt me "{}}";
        sharp  = store_opt me "{#}";

        utf8_char = (fun i -> store_opt me (spr "{utf %d}" i) ());

        link = (fun  kind target text ->
            store_opt me (Commands.Link.unparse kind target text) ());

        start_header = (fun () -> "");
        start_title = (fun () -> "");
        start_authors = (fun () -> "");
        start_subtitle = (fun () -> "");
        stop_header = (fun () -> "");
        stop_title = (fun () -> "");
        stop_authors = (fun () -> "");
        stop_subtitle = (fun () -> "");

        start_image = (fun _ _ _ -> ""); 
        stop_image  = (fun _ _ _ -> ""); 

        print_table = (fun _ _ -> ());

        start_note = (fun () -> "");
        stop_note = (fun () -> "");

    }

)
