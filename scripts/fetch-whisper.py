#!/usr/bin/env python3
"""One-time fetch of the Whisper model + tokenizer for QwenDash.

QwenDash itself never makes network calls. This script populates the
local model cache so the app can run fully offline. Run it once, on a
machine with internet access:

    python3 scripts/fetch-whisper.py

After that the app's voice pipeline loads everything from disk and never
touches the network.

Model variant defaults to `openai_whisper-tiny.en` (~40 MB). Override by
setting WHISPER_VARIANT, e.g.

    WHISPER_VARIANT=openai_whisper-base.en python3 scripts/fetch-whisper.py
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


MODEL_REPO = "argmaxinc/whisperkit-coreml"
TOKENIZER_REPO_DEFAULT = "openai/whisper-tiny.en"
MODEL_VARIANT = os.environ.get("WHISPER_VARIANT", "openai_whisper-tiny.en")

# Tokenizer repo is usually the matching openai/whisper-* repo.
# tiny.en -> openai/whisper-tiny.en, base -> openai/whisper-base, etc.
TOKENIZER_REPO = os.environ.get(
    "WHISPER_TOKENIZER_REPO",
    MODEL_VARIANT.replace("openai_whisper-", "openai/whisper-"),
)

DEST_ROOT = Path.home() / "Library" / "Application Support" / "QwenDash" / "Models"
MODEL_DEST = DEST_ROOT / MODEL_VARIANT
TOKENIZER_DEST = DEST_ROOT / "tokenizer" / TOKENIZER_REPO


def api_tree(repo: str, path: str | None = None) -> list[dict]:
    url = f"https://huggingface.co/api/models/{repo}/tree/main"
    if path:
        url = f"{url}/{path}"
    url += "?recursive=1"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def download(repo: str, remote_path: str, local_path: Path) -> bool:
    if local_path.exists() and local_path.stat().st_size > 0:
        return False
    url = f"https://huggingface.co/{repo}/resolve/main/{remote_path}"
    local_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = local_path.with_suffix(local_path.suffix + ".partial")
    print(f"  {remote_path}")
    urllib.request.urlretrieve(url, tmp_path)
    tmp_path.rename(local_path)
    return True


def fetch(repo: str, prefix: str | None, dest: Path) -> int:
    entries = api_tree(repo, prefix)
    downloaded = 0
    for entry in entries:
        if entry.get("type") != "file":
            continue
        remote = entry["path"]
        rel = remote[len(prefix) + 1:] if prefix and remote.startswith(prefix + "/") else remote
        if download(repo, remote, dest / rel):
            downloaded += 1
    return downloaded


def main() -> int:
    DEST_ROOT.mkdir(parents=True, exist_ok=True)

    print(f"Model     -> {MODEL_DEST}")
    model_n = fetch(MODEL_REPO, MODEL_VARIANT, MODEL_DEST)

    print(f"Tokenizer -> {TOKENIZER_DEST}")
    tok_n = fetch(TOKENIZER_REPO, None, TOKENIZER_DEST)

    print()
    print(f"Done. ({model_n + tok_n} new files)")
    print("QwenDash will now load Whisper entirely from disk.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.URLError as exc:
        print(f"Download failed: {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(130)
