#!/usr/bin/env python3
"""svgview: show an SVG in the terminal and redraw it whenever the file changes.

Made for the lot-map Claude Code plugin, which rewrites its map to
$XDG_RUNTIME_DIR/lot-map/map.svg on every change, but works with any SVG.

Rendering: the SVG is rasterised with rsvg-convert at the terminal's real pixel
size, then sent with the kitty graphics protocol (kitty, Ghostty, WezTerm, Konsole).
In other terminals it falls back to chafa (sixels or Unicode blocks).

Keys: q / Esc / Ctrl-C quit, r forces a redraw.
"""

import argparse
import base64
import fcntl
import os
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time
import tty

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
DEFAULT_SVG = os.path.join(RUNTIME, "lot-map", "map.svg")

ESC = "\x1b"
SYNC_ON, SYNC_OFF = f"{ESC}[?2026h", f"{ESC}[?2026l"
ALT_ON, ALT_OFF = f"{ESC}[?1049h", f"{ESC}[?1049l"
CUR_HIDE, CUR_SHOW = f"{ESC}[?25l", f"{ESC}[?25h"
CLEAR = f"{ESC}[2J"


def out(s: str) -> None:
    os.write(sys.stdout.fileno(), s.encode())


def term_size() -> tuple[int, int, int, int]:
    """(cols, rows, pixel width, pixel height) of the terminal's text area."""
    try:
        rows, cols, xpix, ypix = struct.unpack(
            "HHHH", fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
        )
    except OSError:
        cols, rows = shutil.get_terminal_size()
        xpix = ypix = 0
    if not xpix or not ypix:  # terminal doesn't report pixels: assume a common cell size
        xpix, ypix = cols * 10, rows * 20
    return cols, rows, xpix, ypix


def read_reply(timeout: float, until: bytes) -> bytes:
    """Read terminal replies from stdin until `until` shows up or time runs out."""
    buf = b""
    end = time.monotonic() + timeout
    fd = sys.stdin.fileno()
    while until not in buf:
        left = end - time.monotonic()
        if left <= 0 or not select.select([fd], [], [], left)[0]:
            break
        buf += os.read(fd, 1024)
    return buf


def supports_kitty_graphics() -> bool:
    """Ask the terminal: a graphics query followed by DA1. Kitty-capable terminals
    answer the query first; everything answers DA1, so we never hang."""
    out(f"{ESC}_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA{ESC}\\{ESC}[c")
    reply = read_reply(1.0, b"c")
    return b"_Gi=31;OK" in reply


def png_size(data: bytes) -> tuple[int, int]:
    return struct.unpack(">II", data[16:24])


class Viewer:
    def __init__(self, path: str, background: str | None, status: bool, mode: str):
        self.path = path
        self.background = background
        self.status = status
        self.mode = mode
        self.image_id = 1
        self.stamp: tuple | None = None
        self.last_png: bytes | None = None
        self.message = ""

    # -- rendering -------------------------------------------------------------

    def rasterise(self, w: int, h: int) -> bytes | None:
        cmd = ["rsvg-convert", "-a", "-w", str(w), "-h", str(h), "-f", "png"]
        if self.background:
            cmd += ["-b", self.background]
        try:
            with open(self.path, "rb") as f:
                svg = f.read()
            if not svg.rstrip().endswith(b">"):
                return None  # caught the plugin mid-write; next tick will see the whole file
            r = subprocess.run(cmd, input=svg, capture_output=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired) as e:
            self.message = str(e)
            return None
        if r.returncode != 0 or not r.stdout.startswith(b"\x89PNG"):
            err = r.stderr.decode(errors="replace").strip().splitlines()
            self.message = err[-1] if err else "render failed"
            return None
        self.message = ""
        return r.stdout

    def draw(self) -> None:
        cols, rows, xpix, ypix = term_size()
        text_rows = 1 if self.status else 0
        img_rows = max(1, rows - text_rows)
        cell_w, cell_h = xpix / cols, ypix / rows
        box_w, box_h = int(cols * cell_w), int(img_rows * cell_h)

        png = self.rasterise(box_w, box_h) if os.path.exists(self.path) else None
        frame = [SYNC_ON]

        if png is None and self.last_png is None:
            frame.append(CLEAR + f"{ESC}[H")
            msg = self.message or f"Waiting for {self.path} …"
            frame.append(f"{ESC}[{rows // 2};{max(1, (cols - len(msg)) // 2)}H{msg[:cols]}")
            frame.append(SYNC_OFF)
            out("".join(frame))
            return

        if png is not None:
            self.last_png = png
        png = self.last_png
        pw, ph = png_size(png)
        used_cols = max(1, min(cols, round(pw / cell_w)))
        used_rows = max(1, min(img_rows, round(ph / cell_h)))
        x0 = (cols - used_cols) // 2 + 1
        y0 = (img_rows - used_rows) // 2 + 1

        if self.mode == "kitty":
            frame.append(self.kitty_frame(png, x0, y0, used_cols, used_rows))
        else:
            frame.append(self.chafa_frame(png, x0, y0, used_cols, used_rows))

        if self.status:
            when = time.strftime("%H:%M:%S")
            note = f" {os.path.basename(self.path)} · {when}"
            if self.message:
                note += f" · {self.message}"
            note += "  (q quit, r redraw)"
            frame.append(f"{ESC}[{rows};1H{ESC}[2K{ESC}[2m{note[:cols]}{ESC}[0m")

        frame.append(SYNC_OFF)
        out("".join(frame))

    def kitty_frame(self, png: bytes, x: int, y: int, c: int, r: int) -> str:
        # Two ids, alternating: place the new image, then drop the old one, so the
        # picture never blinks out between frames.
        new_id = 3 - self.image_id
        data = base64.standard_b64encode(png).decode()
        chunks = [data[i : i + 4096] for i in range(0, len(data), 4096)] or [""]
        parts = [f"{ESC}[{y};{x}H"]
        for n, chunk in enumerate(chunks):
            more = 1 if n < len(chunks) - 1 else 0
            if n == 0:
                ctrl = f"a=T,f=100,i={new_id},p=1,q=2,C=1,c={c},r={r},z=-1,m={more}"
            else:
                ctrl = f"m={more}"
            parts.append(f"{ESC}_G{ctrl};{chunk}{ESC}\\")
        parts.append(f"{ESC}_Ga=d,d=I,i={self.image_id},q=2{ESC}\\")
        self.image_id = new_id
        return "".join(parts)

    def chafa_frame(self, png: bytes, x: int, y: int, c: int, r: int) -> str:
        try:
            res = subprocess.run(
                ["chafa", "--size", f"{c}x{r}", "--animate=off", "-"],
                input=png, capture_output=True, timeout=5,
            )
            art = res.stdout.decode(errors="replace")
        except (OSError, subprocess.TimeoutExpired):
            return f"{ESC}[H{CLEAR}No kitty graphics and no chafa: install chafa for this terminal."
        lines = art.rstrip("\n").split("\n")
        if any(l.startswith(f"{ESC}P") for l in lines):  # sixel: one blob, place once
            return f"{ESC}[H{CLEAR}{ESC}[{y};{x}H{art}"
        return f"{ESC}[H{CLEAR}" + "".join(f"{ESC}[{y + i};{x}H{l}" for i, l in enumerate(lines))

    # -- loop ------------------------------------------------------------------

    def file_stamp(self):
        try:
            st = os.stat(self.path)
            return (st.st_mtime_ns, st.st_size, st.st_ino)
        except OSError:
            return None

    def cleanup(self) -> None:
        if self.mode == "kitty":
            out(f"{ESC}_Ga=d,d=A,q=2{ESC}\\")
        out(CLEAR + CUR_SHOW + ALT_OFF)

    def run(self, interval: float, once: bool) -> None:
        resized = [True]
        signal.signal(signal.SIGWINCH, lambda *_: resized.__setitem__(0, True))
        fd = sys.stdin.fileno()
        while True:
            stamp = self.file_stamp()
            if resized[0] or stamp != self.stamp:
                if resized[0]:
                    out(CLEAR)
                    if self.mode == "kitty":
                        out(f"{ESC}_Ga=d,d=A,q=2{ESC}\\")
                resized[0] = False
                self.stamp = stamp
                self.draw()
                if once:
                    return
            try:
                ready = select.select([fd], [], [], interval)[0]
            except InterruptedError:
                continue
            if ready:
                key = os.read(fd, 64)
                if key[:1] in (b"q", b"Q", b"\x03") or key == b"\x1b":
                    return
                if key[:1] in (b"r", b"R"):
                    resized[0] = True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("svg", nargs="?", default=os.environ.get("LOT_MAP_SVG", DEFAULT_SVG),
                    help=f"SVG file to show and watch (default: {DEFAULT_SVG})")
    ap.add_argument("-i", "--interval", type=float, default=0.15,
                    help="seconds between checks for a changed file (default 0.15)")
    ap.add_argument("-b", "--background", help="paint behind the SVG, e.g. '#1f1e1d'")
    ap.add_argument("--no-status", action="store_true", help="hide the bottom status line")
    ap.add_argument("--mode", choices=["auto", "kitty", "chafa"], default="auto",
                    help="graphics method (default: ask the terminal)")
    ap.add_argument("--once", action="store_true", help="draw once and wait for a key")
    args = ap.parse_args()

    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("svgview needs a terminal", file=sys.stderr)
        return 1
    if shutil.which("rsvg-convert") is None:
        print("svgview needs rsvg-convert (librsvg)", file=sys.stderr)
        return 1

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    viewer = None
    try:
        mode = args.mode
        if mode == "auto":
            mode = "kitty" if supports_kitty_graphics() else "chafa"
        viewer = Viewer(args.svg, args.background, not args.no_status, mode)
        out(ALT_ON + CUR_HIDE + CLEAR)
        viewer.run(args.interval, args.once)
        if args.once:
            os.read(fd, 64)
    except KeyboardInterrupt:
        pass
    finally:
        if viewer:
            viewer.cleanup()
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
    return 0


if __name__ == "__main__":
    sys.exit(main())
