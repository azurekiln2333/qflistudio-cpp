import os
import signal
import subprocess
import sys
import time

here = os.path.dirname(os.path.abspath(__file__))
mode, child_mode = sys.argv[1], sys.argv[2]
if mode == 'wait':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
child = subprocess.Popen([sys.executable, os.path.join(here, 'child.py'),
                          child_mode, '60'])
sys.stdout.write('spawned %d\n' % child.pid)
sys.stdout.flush()
time.sleep(60 if mode == 'wait' else 0.3)
