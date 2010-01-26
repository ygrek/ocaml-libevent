(* 
 * Simple but fast HTTP Server 
 *)

let accept fd = 
  let client_fd, client_addr = Unix.accept fd in  
    Unix.set_nonblock client_fd;
    client_fd, client_addr

let http_server_cb buffer buflen fd event_type =
  let client_fd, client_addr = accept fd in

  let read_event = Libevent.create () in
  let write_event = Libevent.create () in
      
  (* The http connection callback *)
  let http_read_cb fd event_type =
    let len = Unix.read fd buffer 0 buflen in

    (* HTTP Request not parsed, does not even have to be complete yet.*)
    let http_write_cb fd event_type = 
      let response = "HTTP/1.0 200 OK\n\r" ^
	"Server: Caml 1.0\r\n" ^
	"\r\n" ^
	"<html><h1>Hi There</h1>" ^
	"<pre>" ^ (String.sub buffer 0 len) ^ "</pre>" ^ 
        "</html"
      in
      let l = Unix.write fd response 0 (String.length response) in
	Unix.close fd
    in
      Libevent.set write_event fd [Libevent.WRITE] false http_write_cb;
      Libevent.add write_event None

  in
    Libevent.set read_event client_fd [Libevent.READ] false http_read_cb;
    Libevent.add read_event None
  
let bind_server port = 
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Unix.set_nonblock fd; 
    Unix.setsockopt fd Unix.SO_REUSEADDR true;
    Unix.bind fd (Unix.ADDR_INET (Unix.inet_addr_any, port));
    Unix.listen fd 5;
    fd

let _ =
  Unix.set_nonblock Unix.stdout;
  Unix.set_nonblock Unix.stderr;

  let server_event = Libevent.create () in
  let stdout_event = Libevent.create () in
  let stderr_event = Libevent.create () in

  let server_fd = bind_server 8080 in
    
  let buflen = 10240 in
  let buffer = String.create buflen in 

    Libevent.set server_event server_fd [Libevent.READ] true 
      (http_server_cb buffer buflen);
    Libevent.add server_event None;

    Libevent.dispatch ();
