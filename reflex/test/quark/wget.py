#!/usr/bin/env python

# Quark is Copyright (C) 2012-2015, Quark Team.
#
# You can redistribute and modify it under the terms of the GNU GPL,
# version 2 or later, but it is made available WITHOUT ANY WARRANTY.
#
# For more information about Quark, see our web site at:
# http://goto.ucsd.edu/quark/


import sys
import os
import subprocess
import cPickle as pickle

user_agent = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/534.30 (KHTML, like Gecko) Ubuntu/11.04 Chromium/12.0.742.112 Chrome/12.0.742.112 Safari/534.30"

def get_uri(uri):
    # The following would have avoived going to disk, but unfortunately,
    # wget does not perform link-conversion when outputting to stdout
    # html = subprocess.Popen(
    #     ['/usr/bin/wget',
    #      '-q',
    #      '--convert-links',
    #      '-O', '-',
    #      '-U', user_agent,
    #      uri], 
    #     bufsize = 1, 
    #     stdin = subprocess.PIPE, 
    #     stdout = subprocess.PIPE).communicate()[0]
    fname = "webfile"
    subprocess.call(
        ['/usr/bin/wget',
         '--tries=1',
         '--timeout=0.5',
         '-q',
         '--convert-links',
         '-O', fname,
         '-U', user_agent,
         uri])
    f = open(fname)
    content = f.read()
    f.close()
    return content

f = os.fdopen(int(sys.argv[1]), 'w')
pickle.dump(get_uri(sys.argv[3]), f)
#print get_uri(sys.argv[1])

#USER_AGENT="Mozilla/5.0 (X11; Linux i686) AppleWebKit/534.30 (KHTML, like Gecko) Ubuntu/11.04 Chromium/12.0.742.112 Chrome/12.0.742.112 Safari/534.30"
#echo "=============================================" >> wget.out
#echo "ORIGIN:$1" >> wget.out
#/usr/bin/wget --tries=1 --timeout=2 --server-response --convert-links -a wget.out -O webfile -U "$USER_AGENT" $2 2>>wget.err

