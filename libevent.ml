(***********************************************************************)
(* The OcamlEvent library                                              *)
(*                                                                     *)
(* Copyright 2002, 2003 Maas-Maarten Zeeman. All rights reserved. See  *) 
(* LICENCE for details.                                                *)
(***********************************************************************)

(* $Id: liboevent.ml,v 1.1 2009-11-26 08:49:02 maas Exp $ *)
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

type event_callback = event -> Unix.file_descr -> event_flags -> unit

(* Use an internal hashtable to store the ocaml callbacks with the
   event *)
let table = Hashtbl.create 0

(* Called by the c-stub, locate, and call the ocaml callback *)
let event_cb event_id fd etype =
  let (event,cb) = Hashtbl.find table event_id in
  cb event fd (event_type_of_int etype)

(* Return the id of an event *)
external event_id : event -> int = "oc_event_id"

(* Return the signal associated with the event *)
external signal : event -> int = "oc_event_fd"

(* Return the fd associated with the event *)
external fd : event -> Unix.file_descr = "oc_event_fd"

(* Set an event (not exported) *)
external cset_fd : event_base -> Unix.file_descr -> int -> event = "oc_event_create"
external cset_int : event_base -> int -> int -> event = "oc_event_create"

let persist_flag = function true -> 0x10 | false -> 0

(* Create events *)
let create event_base fd etype persist (cb : event_callback) =
  let rec int_of_event_type_list flag = function
      h::t -> int_of_event_type_list (flag lor (int_of_event_type h)) t
    | [] -> flag
  in
  let flag = int_of_event_type_list (persist_flag persist) etype in
  let event = cset_fd event_base fd flag in
  Hashtbl.add table (event_id event) (event,cb);
  event

let create_timer event_base persist (cb : event -> unit) =
  let flag = persist_flag persist in
  let event = cset_int event_base (-1) flag in
  Hashtbl.add table (event_id event) (event, (fun e _ _ -> cb e));
  event

let create_signal event_base signal persist (cb : event_callback) =
  let flag = (int_of_event_type SIGNAL) lor (persist_flag persist) in
  let event = cset_int event_base signal flag in
  Hashtbl.add table (event_id event) (event,cb);
  event

(* Add an event *)
external add : event -> float option -> unit = "oc_event_add"

(* Del an event  *)
external cdel : event -> unit = "oc_event_del"
let del event =
  Hashtbl.remove table (event_id event);
  cdel event

(* *)
(* Not fully implemented yet *)
external pending : event -> event_flags list -> bool = "oc_event_pending"

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

let create = create base
let dispatch () = dispatch base
let loop = loop base

end

