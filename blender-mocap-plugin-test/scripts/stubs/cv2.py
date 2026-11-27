"""Minimal cv2 stub for MediaPipe Tasks API (drawing helpers only).

Only present so `import mediapipe` (which imports solutions -> drawing_utils)
succeeds. Pose/hand landmark inference does not call OpenCV. Do not use for
image IO/drawing.
"""
import numpy as np
__version__ = "0.0-stub"
LINE_AA = 16
FILLED = -1
FONT_HERSHEY_SIMPLEX = 0
FONT_HERSHEY_PLAIN = 1
FONT_HERSHEY_DUPLEX = 2
def line(*a, **k): pass
def circle(*a, **k): pass
def putText(*a, **k): pass
def rectangle(*a, **k): pass
def arrowedLine(*a, **k): pass
def imwrite(*a, **k): return False
def imread(*a, **k): return None
def resize(img, *a, **k): return img
def cvtColor(img, *a, **k): return img
def addWeighted(a, *args, **kwargs): return a
def applyColorMap(img, *a, **k): return img
def polylines(*a, **k): pass
