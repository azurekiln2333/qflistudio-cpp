import signal
import sys
import time

mode = sys.argv[1]
if mode == 'ignore-term':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
time.sleep(float(sys.argv[2]))
