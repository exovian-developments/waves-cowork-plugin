#!/bin/bash
# scope-resolve.sh — SHIM (w6 Phase 13): the rail moved to the kernel.
#
# The real implementation now lives at plugin/kernel/lib/scope-resolve.sh (the
# self-contained waves_kernel). This shim exists so the 10 consuming hooks keep
# their `source "${CLAUDE_PLUGIN_ROOT}/hooks/_lib/scope-resolve.sh"` line
# unchanged — zero-regression extraction. New consumers should source the
# kernel copy directly. Caller contract (export SESSION_ID first) unchanged.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kernel/lib" && pwd)/scope-resolve.sh"
