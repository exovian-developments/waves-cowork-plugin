#!/bin/bash
# thread-resolve.sh — SHIM (w6 Phase 13): the rail moved to the kernel.
#
# The real implementation now lives at plugin/kernel/lib/thread-resolve.sh.
# This shim keeps existing `source .../hooks/_lib/thread-resolve.sh` consumers
# working unchanged (zero-regression extraction). Caller contract (export
# SESSION_ID first) unchanged.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kernel/lib" && pwd)/thread-resolve.sh"
