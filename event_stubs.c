/************************************************************************/
/* The OcamlEvent library                                               */
/*                                                                      */
/* Copyright 2002, 2003, 2004 Maas-Maarten Zeeman. All rights reserved. */
/* See LICENCE for details.                                             */
/************************************************************************/

/* $Id: event_stubs.c,v 1.2 2009-11-26 08:41:10 maas Exp $ */

/* Stub code to interface Ocaml with libevent */

#include <sys/time.h>
#include <stdlib.h>
#include <event.h>
#include <string.h>

#include <caml/mlvalues.h>
#include <caml/custom.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/callback.h>
#include <caml/fail.h>
#include <caml/unixsupport.h>
#include <caml/signals.h>

#define struct_event_val(v) (*(struct event**) Data_custom_val(v))
#define Is_some(v) (Is_block(v))

/* FIXME use custom block */
#define struct_event_base_val(v) (struct event_base*)(v)
#define Val_struct_event_base(base) ((value)(base))

static value * event_cb_closure = NULL;

/* FIXME use dedicated exception */
static void raise_error(char const* str, char const* arg)
{
  uerror((char*)str, NULL == arg ? Nothing : caml_copy_string(arg));
}

static void
struct_event_finalize(value ve) 
{
  struct event *ev = struct_event_val(ve);

  if (event_initialized(ev)) {
    event_del(ev);
  }

  caml_stat_free(struct_event_val(ve));
}

static int 
struct_event_compare(value v1, value v2) 
{ 
  struct event *p1 = struct_event_val(v1);
  struct event *p2 = struct_event_val(v2);
  if(p1 == p2) return 0;
  if(p1 < p2) return -1; 
  return 1;
}

static long
struct_event_hash(value v)
{
  return (long) struct_event_val(v);
}

static struct custom_operations struct_event_ops = {
  "struct event",
  struct_event_finalize,
  struct_event_compare,
  struct_event_hash,
  custom_serialize_default,
  custom_deserialize_default
};

/* 
 * This callback calls the ocaml event callback, which will in turn
 * call the real ocaml callback.  
 */
static void
event_cb(int fd, short type, void *arg) 
{
  caml_leave_blocking_section();
  callback3(*event_cb_closure, 
	    Val_long((long) arg), Val_int(fd), Val_int(type));
  caml_enter_blocking_section();
}

static void
set_struct_timeval(struct timeval *tv, value vfloat) 
{
  double timeout = Double_val(vfloat);
  tv->tv_sec = (int) timeout;
  tv->tv_usec = (int) (1e6 * (timeout - tv->tv_sec));
}

CAMLprim value
oc_create_event(value u)
{
  CAMLparam1(u);
  CAMLlocal1(ve);
  struct event* ev = caml_stat_alloc(sizeof(struct event));
  memset(ev, 0, sizeof(*ev));

  ve = caml_alloc_custom(&struct_event_ops, sizeof(struct event*), 0, 1);
  struct_event_val(ve) = ev;

  CAMLreturn(ve);
}

CAMLprim value
oc_event_id(value vevent)
{
  CAMLparam0();
  CAMLreturn(Val_long((long) struct_event_val(vevent)));
}

CAMLprim value
oc_event_fd(value vevent)
{
  CAMLparam1(vevent);
  CAMLreturn(Val_long(EVENT_FD(struct_event_val(vevent))));
}

CAMLprim value 
oc_event_set(value vbase, value vevent, value fd, value vevent_flag)
{ 
  CAMLparam4(vbase, vevent, fd, vevent_flag);

  struct event *event = struct_event_val(vevent); 

  event_set(event, Int_val(fd), Int_val(vevent_flag), 
	    &event_cb, event); 

  if (0 != event_base_set(struct_event_base_val(vbase), event))
  {
    raise_error("event_set", "event_base_set");
  }

  CAMLreturn(Val_unit); 
} 

CAMLprim value
oc_event_add(value vevent, value vfloat_option)
{
  CAMLparam2(vevent, vfloat_option);
  struct event *event = struct_event_val(vevent);
  struct timeval timeval;
  struct timeval *tv = NULL;

  if (Is_some(vfloat_option)) {
    set_struct_timeval(&timeval, Field(vfloat_option, 0));
    tv = &timeval;
  }

  if (0 != event_add(event, tv)) {
    raise_error("event_add", "event_add");
  }

  CAMLreturn(Val_unit);
}

CAMLprim value
oc_event_del(value vevent) 
{
  CAMLparam0();
  struct event *event = struct_event_val(vevent); 

  event_del(event);

  CAMLreturn(Val_unit);
}

CAMLprim value
oc_event_pending(value vevent, value vtype, value vfloat_option) 
{
  CAMLparam3(vevent, vtype, vfloat_option);
  struct event *event = struct_event_val(vevent); 
  struct timeval timeval;
  struct timeval *tv = NULL;
  
  if Is_some(vfloat_option) {
    set_struct_timeval(&timeval, Field(vfloat_option, 0));
    tv = &timeval;
  } 

  event_pending(event, Int_val(vtype), tv);

  CAMLreturn(Val_unit);
}

CAMLprim value
oc_event_base_loop(value vbase, value vloop_flag)
{
  CAMLparam2(vbase,vloop_flag);
  struct event_base* base = struct_event_base_val(vbase);

  caml_enter_blocking_section();
  if((-1 == event_base_loop(base,Int_val(vloop_flag)))) {
    caml_leave_blocking_section();
    raise_error("event_loop", NULL);
  }
  caml_leave_blocking_section();

  CAMLreturn(Val_unit);
}


CAMLprim value
oc_event_base_dispatch(value vbase) 
{
  CAMLparam1(vbase);
  struct event_base* base = struct_event_base_val(vbase);

  caml_enter_blocking_section();
  if((-1 == event_base_dispatch(base))) {
    caml_leave_blocking_section();
    raise_error("event_dispatch", NULL);
  }
  caml_leave_blocking_section();

  CAMLreturn(Val_unit);
}

/*
 * Initialize event base
 */
CAMLprim value
oc_event_base_init(value unit)
{
  CAMLparam1(unit);
  struct event_base* base = NULL;

  /* setup the event callback closure if needed */
  if(event_cb_closure == NULL) {
    event_cb_closure = caml_named_value("event_cb");
    if(event_cb_closure == NULL) {
      invalid_argument("Callback event_cb not initialized.");
    }
  }

  base = event_base_new();
  if (!base) {
    raise_error("event_base_init", NULL);
  }

  CAMLreturn(Val_struct_event_base(base));
}

CAMLprim value
oc_event_base_reinit(value vbase)
{
  CAMLparam1(vbase);
  struct event_base* base = struct_event_base_val(vbase);

  if (0 != event_reinit(base)) {
    raise_error("event_base_reinit", NULL);
  }

  CAMLreturn(Val_unit);
}

CAMLprim value
oc_event_base_free(value vbase)
{
  CAMLparam1(vbase);
  struct event_base* base = struct_event_base_val(vbase);

  event_base_free(base);

  CAMLreturn(Val_unit);
}

