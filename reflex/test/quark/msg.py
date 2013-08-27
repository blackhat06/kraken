#!/usr/bin/env python

import socket, os, os.path, sys, re, time
import struct, passfd, atexit

Display     = "Display"
Navigate    = "Navigate"
ReqResource = "ReqResource"
ResResource = "ResResource"
ReqSocket   = "ReqSocket"
ResSocket   = "ResSocket"
SetDomain   = "SetDomain"
KeyPress    = "KeyPress"
MouseClick  = "MouseClick"
Go          = "Go"
NewTab      = "NewTab"

FD    = None
KCHAN = None
PROG  = None
LOG   = None

def init():
  global FD, KCHAN, PROG, LOG

  # set up communication with kernel
  FD = int(sys.argv[1])
  KCHAN = socket.fromfd(FD, socket.AF_UNIX, socket.SOCK_STREAM)

  # set up logging
  PROG = os.path.basename(sys.argv[0])
  path = os.path.join(os.environ['KRAKEN'], 'log', '%s-%d-log' % (PROG, FD))
  LOG  = open(path, 'w', 0) # unbuffered

  # tear down at exit
  atexit.register(lambda: KCHAN.close())
  atexit.register(lambda: LOG.close())

def log(msg):
  #LOG.write(msg)
  # FD - 1 should be the kernel's pipe for this component
  LOG.write('%15s @ %f || %s\n' %
     ('%s(%d)' % (PROG, FD - 1), time.time(), msg))

def recv_num():
  s = KCHAN.recv(2)
  n = struct.unpack('>H', s)[0]
  return n

def recv_str():
  n = recv_num()
  s = KCHAN.recv(n)
  return s

def recv_fd():
  fd, _ = passfd.recvfd(KCHAN)
  f = os.fdopen(fd, 'r')
  return f

def send_num(n):
  s = struct.pack('>H', n)
  KCHAN.send(s)

def send_str(s):
  send_num(len(s))
  KCHAN.send(s)

def send_fd(f):
  fd = f.fileno()
  passfd.sendfd(KCHAN, fd)

def msg_str(m):
  def param_str(p):
    if isinstance(p, int):
      return '%d' % p
    elif isinstance(p, str):
      p = re.escape(p)
      p = p.replace('\n', '\\n')
      return '"%s"' % p
    else:
      # assume fd
      return 'fd(%d)' % p.fileno()
  params = ", ".join(map(param_str, m[1:]))
  return '%s(%s)' % (m[0], params)

def recv():
  tag = recv_num()
  m = {
    0 : lambda : [Display, recv_str()],
    1 : lambda : [Navigate, recv_str()],
    2 : lambda : [ReqResource, recv_str()],
    3 : lambda : [ResResource, recv_fd()],
    4 : lambda : [ReqSocket, recv_str()],
    5 : lambda : [ResSocket, recv_str()],
    6 : lambda : [SetDomain, recv_str()],
    7 : lambda : [KeyPress, recv_str()],
    8 : lambda : [MouseClick, recv_str(), recv_str(), recv_num()],
    9 : lambda : [Go, recv_str()],
   10 : lambda : [NewTab]
  }[tag]()
  log('recv : %s' % msg_str(m))
  return m

def send(*m):
  tag = m[0]
  {
    Display     : lambda : [send_num(0), send_str(m[1])],
    Navigate    : lambda : [send_num(1), send_str(m[1])],
    ReqResource : lambda : [send_num(2), send_str(m[1])],
    ResResource : lambda : [send_num(3), send_fd(m[1])],
    ReqSocket   : lambda : [send_num(4), send_str(m[1])],
    ResSocket   : lambda : [send_num(5), send_str(m[1])],
    SetDomain   : lambda : [send_num(6), send_str(m[1])],
    KeyPress    : lambda : [send_num(7), send_str(m[1])],
    MouseClick  : lambda : [send_num(8), send_str(m[1]), send_str(m[2]), send_num(m[3])],
    Go          : lambda : [send_num(9), send_str(m[1])],
    NewTab      : lambda : [send_num(10)]
  }[tag]()
  log('send : %s' % msg_str(m))
