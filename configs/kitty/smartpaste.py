import subprocess

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    try:
        types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=1).stdout.split()
    except Exception:
        types = []
    if any(t.startswith("image/") for t in types) and "text/plain" not in types:
        w.send_key("ctrl+v")
    else:
        boss.combine("paste_from_clipboard", window_for_dispatch=w)
