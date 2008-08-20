module Sig = Signatures

module FunctorMake =
functor (Printer: Sig.PRINTER) -> struct
    type t = {
        t_printer: Printer.t;
        t_read: unit -> string option;
        t_write: string -> unit;
    }
    let create ~read ~write = {
        t_printer = Printer.create ~write; t_read = read; t_write = write;
    }

    let make_state l c s =
        {Sig.s_line = l; s_char = c; s_stack = s;}

    type parser_state =
        | Undef (* should not be used at the end *)
        | Terminated
        | ReadText of int
        | ReadCommand of int * string option (* the current read name *)
        | ReadArgs of int * string * string list * string option
        (* ReadArgs (since, cmd_name, arg_list, current_arg *)

    let get_arguments s index = (
        let rec get_args prev i acc =
            match String.get s i with
            | '}' -> 
                    let l = ((prev, (i-1)) :: acc) in
                    if try String.get s (i+1) = '{' with e -> false then (
                        (* continue for another arg *)
                        get_args (i+2) (i+2) l
                    ) else (
                        (* finish *)
                        l
                    )
            | _ -> 
                    get_args prev (i+1) acc
        in
        if String.get s index = '{' then (
            (* there are arguments *)
            get_args (index + 1) (index + 1) []
        ) else (
            []
        )
    )

    let get_command_name s index = (
        let rec parse i =
            if i < (String.length s) then
                match String.get s i with
                | ':' | '{' -> Some i
                | _ -> parse (i+1)
            else
                None
        in
        parse index
    )


    let parse_line_old t line number state = (
        let module S = String in
        (* let i = ref 0 in *)
        let l = S.length line in
        let rec loop (i, state) =
            if i < l then
                loop begin match S.get line i with
                | '#' ->
                        Printer.handle_comment_line t.t_printer
                            (make_state number i [])
                            (S.sub line i (l - i));
                        (l, state)
                | '{' ->
                        (* begin read command *)
                        (* TODO read command and change state *)
                        begin match get_command_name line i with
                        | Some name_end_index ->
                                let args = get_arguments line name_end_index in
                                let after_command =
                                    match args with
                                    | [] -> name_end_index
                                    | (b,e) :: t -> e + 1
                                in
                                (after_command, ReadText after_command)
                        | None ->
                                (* TODO must flush text, pop command *)
                                (i + 1, ReadText (i + 1))
                        end
                | '}' ->
                        (* end command *)
                        (* TODO must flush text, pop command *)
                        (i + 1, ReadText (i + 1))
                | ' ' | '\n' | '\r' | '\t' ->
                        (* white space *)
                        (i + 1, Undef)
                | _ ->
                        (* characters *)
                        (i + 1, Undef)
                end
            else
                (* TODO if TextRead: must flush text *)
                state
        in loop (0, state)
    )

    module Str = String (* to be able to swicth easily *)

    let parse_line t line number state = (
        (* let i = ref 0 in *)
        let l = Str.length line in
        let sub s since = Str.sub s since (l - since) in
        let rec loop (i, state) =
            if i < l then
                loop begin match Str.get line i with
                | '#' ->
                        Printer.handle_comment_line t.t_printer
                            (make_state number i []) (sub line i);
                        (l, state)
                | '{' ->
                        (* begin read command *)
                        (* TODO read command and change state *)
                        begin match get_command_name line i with
                        | Some name_end_index ->
                                let args = get_arguments line name_end_index in
                                let after_command =
                                    match args with
                                    | [] -> name_end_index
                                    | (b,e) :: t -> e + 1
                                in
                                (after_command, ReadText after_command)
                        | None ->
                                (* TODO must flush text, pop command *)
                                (i + 1, ReadText (i + 1))
                        end
                | '}' ->
                        (* end command *)
                        (* TODO must flush text, pop command *)
                        (i + 1, ReadText (i + 1))
                | ' ' | '\n' | '\r' | '\t' ->
                        (* white space *)
                        (i + 1, Undef)
                | _ ->
                        (* characters *)
                        (i + 1, Undef)
                end
            else (
                (* EOL *)
                let next_state =
                    match state with
                    | ReadText i -> (* TODO flush text *) ReadText 0
                    | ReadCommand (since, Some s) ->
                            ReadCommand (0, Some (s ^ (sub line since))) 
                    | ReadCommand (since, None) ->
                            ReadCommand (0, Some (sub line since))
                    | ReadArgs (since, cmd_name, arg_list, Some c_arg) ->
                            ReadArgs (0, cmd_name, arg_list,
                                Some (c_arg ^ (sub line since)))
                    | s -> s
                in
                next_state
            )
        in loop (0, state)
    )
    let do_transformation t = (
        let rec while_loop lineno state = 
            match t.t_read () with
            | Some s ->
                    let new_state =
                        parse_line t s lineno state in
                    while_loop (lineno + 1) new_state
            | None -> ()
        in
        while_loop 1 (ReadText 0);
    )
end

module Make =
    (FunctorMake: functor (Printer: Sig.PRINTER) -> (Sig.TRANSFORMER))
    (* with type t = FunctorMake.t)) *)
