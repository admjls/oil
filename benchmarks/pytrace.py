#!/usr/bin/python
"""
pytrace.py
"""

import cStringIO
import os
import struct
import sys

# TODO: Two kinds of tracing?
# - FullTracer -> Chrome trace?
# - ReservoirSamplingTracer() -- flame graph that is deterministic?

# TODO: Check this in but just go ahead and fix wild.sh instead.


class Tracer(object):
  # Limit to 10M events by default.
  def __init__(self, max_events=10e6):
    self.pid = os.getpid()
    # append 
    self.event_strs = cStringIO.StringIO()

    # After max_events we stop recording
    self.max_events = max_events
    self.num_events = 0

  # Python VM callback
  def OnEvent(self, frame, event_type, arg):
    # Test overhead
    # 7.5 seconds.  Geez.  That's crazy high.
    # The baseline is 2.7 seconds, and _lsprof takes 3.8 seconds.

    # I guess that's why pytracing is a decorator and only works on one part of
    # the program.
    # pytracing isn't usable with large programs.  It can't run abuild -h.

    # What I really want is the nicer visualization.  I don't want the silly
    # cProfile output.

    self.num_events += 1
    return

    self.event_strs.write('')  # struct.pack(s)
    # TODO:

  def Start(self):
    sys.setprofile(self.OnEvent)

  def Stop(self, path):
    # Only one process should write out the file!
    if os.getpid() != self.pid:
      return

    # TODO:
    # - report number of events?
    # - report number of bytes?
    print >>sys.stderr, 'num_events: %d' % self.num_events
    print >>sys.stderr, 'Writing to %r' % path
    with open(path, 'w') as f:
      f.write(self.event_strs.getvalue())


def main(argv):
  t = Tracer()
  import urlparse
  t.Start()
  print urlparse.urlparse('http://example.com/foo')
  t.Stop('demo.pytrace')


if __name__ == '__main__':
  try:
    main(sys.argv)
  except RuntimeError as e:
    print >>sys.stderr, 'FATAL: %s' % e
    sys.exit(1)