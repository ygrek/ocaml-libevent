(***********************************************************************)
(* The ocaml-event library                                             *)
(*                                                                     *)
(* Copyright 2002, 2003 Maas-Maarten Zeeman. All rights reserved.      *)
(* Copyright 2010 ygrek                                                *)
(* See LICENCE for details.                                            *)
(***********************************************************************)

type event
type event_base

type event_flags =
    TIMEOUT
  | READ
  | WRITE
  | SIGNAL

let int_of_event_type = function
    TIMEOUT -> 0x01
  | READ -> 0x02
  | WRITE -> 0x04
  | SIGNAL -> 0x08

let event_type_of_int = function
  | 1 -> TIMEOUT
  | 2 -> READ
  | 4 -> WRITE
  | 6 -> READ (* READ|WRITE *)
  | 8 -> SIGNAL
  | n -> raise (Invalid_argument (Printf.sprintf "event_type %d" n))

type event_callback = Unix.file_descr -> event_flags -> unit

(* Use an internal hashtable to store the ocaml callbacks with the
   event *)
let table = Hashtbl.create 0

(* Called by the c-stub, locate, and call the ocaml callback *)
let event_cb event_id fd etype =
  let k =
    try Hashtbl.find table event_id
    with Not_found -> (fun _ _ -> ()) (* it may happen, cf. activate *)
  in
  k fd (event_type_of_int etype)

(* Create an event *)
external create : unit -> event = "oc_create_event"

(* Return the id of an event *)
external event_id : event -> int = "oc_event_id"

(* Return the signal associated with the event *)
external signal : event -> int = "oc_event_fd"

(* Return the fd associated with the event *)
external fd : event -> Unix.file_descr = "oc_event_fd"

(* Set an event (not exported) *)
external cset_fd : event_base -> event -> Unix.file_descr -> int -> unit = "oc_event_set"
external cset_int : event_base -> event -> int -> int -> unit = "oc_event_set"

let persist_flag = function true -> 0x10 | false -> 0

let rec int_of_event_type_list flag = function
| h::t -> int_of_event_type_list (flag lor (int_of_event_type h)) t
| [] -> flag

(* Event set *)
let set base event fd etype persist (cb : event_callback) =
  let flag = int_of_event_type_list (persist_flag persist) etype in
  Hashtbl.replace table (event_id event) cb;
  cset_fd base event fd flag

let set_timer base event persist (cb : unit -> unit) =
  let flag = persist_flag persist in
  Hashtbl.replace table (event_id event) (fun _ _ -> cb ());
  cset_int base event (-1) flag

let set_signal base event signal persist (cb : event_callback) =
  let flag = (int_of_event_type SIGNAL) lor (persist_flag persist) in
  Hashtbl.replace table (event_id event) cb;
  cset_int base event signal flag

(* Add an event *)
external add : event -> float option -> unit = "oc_event_add"

(* Del an event  *)
external cdel : event -> unit = "oc_event_del"
let del event =
  Hashtbl.remove table (event_id event);
  cdel event

(* Check whether event is pending *)
external cpending : event -> int -> bool = "oc_event_pending"
let pending event flags = cpending event (int_of_event_type_list 0 flags)

external cactive : event -> int -> unit = "oc_event_active"
let activate event flags = cactive event (int_of_event_type_list 0 flags)

(* Process events *)
external dispatch : event_base -> unit = "oc_event_base_dispatch"

type loop_flags = ONCE | NONBLOCK
external loop : event_base -> loop_flags -> unit = "oc_event_base_loop"

external init : unit -> event_base = "oc_event_base_init"
external reinit : event_base -> unit = "oc_event_base_reinit"
external free : event_base -> unit = "oc_event_base_free"

let () =
  Callback.register "event_cb" event_cb

(** Compatibility *)
module Global = struct

let base = init ()
let init () = reinit base

let set = set base
let dispatch () = dispatch base
let loop = loop base

end
