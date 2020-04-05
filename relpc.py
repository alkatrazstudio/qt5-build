#!/usr/bin/env python3

import os
import re
import shutil
import sys
import tempfile


def find_files(root_dir):
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".pc"):
                yield root + "/" + file


def read_lines(filename):
    with open(filename) as f:
        for line in f:
            yield line


def generate_updated_file(filename):
    with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
        for line in read_lines(filename):
            m = re.search(r"^(\s*prefix\s*=\s*)([^$]+)$", line)
            if m:
                prefix = m.group(2).rstrip()
                file_dir = os.path.dirname(filename)
                rel_dir = os.path.relpath(prefix, file_dir)
                if rel_dir == ".":
                    new_prefix = "${pcfiledir}"
                else:
                    new_prefix = "${pcfiledir}/" + rel_dir
                new_line = m.group(1) + new_prefix + "\n"
            else:
                new_line = line
            f.write(new_line)
    return f.name


def patch_file(filename):
    patched_filename = generate_updated_file(filename)
    shutil.move(patched_filename, filename)


def patch_all_files(root_dir):
    for filename in find_files(root_dir):
        patch_file(filename)


if __name__ == "__main__":
    root_dir = sys.argv[1]
    patch_all_files(root_dir)
