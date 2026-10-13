#!/usr/bin/env python3
"""Fail the PR if a commit has no Story trailer. Tooling/docs commits use 'Story: N/A'."""
import re, subprocess, sys
base, head = sys.argv[1], sys.argv[2]
git = lambda *a: subprocess.check_output(["git", *a], text=True)
bad = []
for sha in git("rev-list", f"{base}..{head}").split():
    msg = git("log", "-1", "--format=%B", sha)
    if not re.search(r"^Story:\s*(US-\d{3}|N/A)", msg, re.M):
        bad.append(sha[:8] + " " + msg.splitlines()[0])
if bad:
    print("Commits without a 'Story:' trailer:\n- " + "\n- ".join(bad)); sys.exit(1)
print("Traceability check passed")
