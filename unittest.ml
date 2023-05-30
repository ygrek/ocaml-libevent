(***********************************************************************)
(* The ocaml-libevent library                                          *)
(*                                                                     *)
(* Copyright 2002, 2003 Maas-Maarten Zeeman. All rights reserved. See  *)
(* LICENCE for details.                                                *)
(***********************************************************************)

open OUnit
open Libevent

(* Tests the creation of new events *)
let test_create_event () =
  let e1 = create () in
  let e2 = create () in
  "Events should be different" @? (e1 <> e2)

let test_pending () =
  let base = init () in
  let e = create () in
  let all = [READ;WRITE;SIGNAL;TIMEOUT] in
  "Fresh event is not pending" @? (false = pending e all);
  set_timer base e ~persist:true (fun () -> assert false);
  "Still not pending" @? (false = pending e all);
  add e (Some 120.);
  "Pending on some type" @? (pending e all);
  "Pending on TIMEOUT" @? (pending e [TIMEOUT]);
  "Not pending on READ" @? (false = pending e [READ]);
  "Not pending on empty flags" @? (false = pending e []);
  del e;
  "Not pending on any type" @? (false = pending e all);
  free base;
  (** cannot access events after base is freed. TODO add safety test in stubs? *)
  ()

(* Test eof on a read callback *)
let test_read_eof () =
  let test_string = "This is a test string\n\n\n" in
  let buflen = 512 in
  let buf = Bytes.create buflen in
  let read_count = ref 0 in
  let evt = create () in
  let read_cb fd event_type =
    (* read data from the fd *)
    let len = Unix.read fd buf 0 buflen in
    (* when 0 bytes are read this is the EOF, and we are done. *)
    if len <> 0 then
    begin
      read_count := !read_count + len;
      add evt None
    end
  in

  (* Create a socket pair for testing *)
  let s1, s2 = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  let _ = Unix.write_substring s1 test_string 0 (String.length test_string) in

  (* A shutdown_send will cause an EOF on the reading end *)
  Unix.shutdown s1 Unix.SHUTDOWN_SEND;

  (* Setup the event *)
  Global.set evt s2 [READ] ~persist:false read_cb;
  add evt None;
  Global.dispatch ();

  (* Now its time to check some things *)
  assert_equal (String.length test_string) ! read_count

(* This is not really a test (yet) *)
let call_set () =
  let do_nothing _ _ =
    ()
  in
  let e1 = create () in
  Global.set e1 Unix.stderr [WRITE] ~persist:false do_nothing;
  Global.set e1 Unix.stdout [WRITE] ~persist:false do_nothing;
  Global.set e1 Unix.stdin [READ] ~persist:false do_nothing;
  add e1 (Some 0.1);
  Global.loop ONCE

let test_free () =
  let base = init () in
  let ev = create () in
  let called = ref 0 in
  set_timer base ev ~persist:true (fun () -> incr called);
  add ev (Some 1.);
  loop base ONCE;
  "callback called once as expected" @? (!called = 1);
  Gc.compact (); (* make sure all events are gone before freeing base *)
  free base;
  Gc.compact ();
  "reached end with callback called once as expected" @? (!called = 1)

(* Construct the test suite *)
let suite = "event" >:::
  ["create_event" >:: test_create_event;
   "test_pending" >:: test_pending;
   "test_read_eof" >:: test_read_eof;
   "call_set" >:: call_set;
   "event_base_free" >:: test_free;
 ]

(* Run the tests in the test suite *)
let _ =
  run_test_tt_main suite
