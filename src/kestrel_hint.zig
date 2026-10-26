//! Kestrel per-task scheduling hint.
//!
//! Sets the hint the Kestrel kernel stores on a task
//! (sched_attr::sched_ext_hint, SCHED_FLAG_KESTREL_HINT) so scx_kestrel can
//! classify the terminal. A stock kernel rejects the flag, so the call fails
//! harmlessly and the broker's cgroup classification stands on its own.
//!
//! Keep the ABI in sync with kestrel-distro/kestrel
//! install/helpers/libkestrel-hint/kestrel_hint.h and the kernel patch.

const std = @import("std");
const builtin = @import("builtin");

const FLAG: u64 = 1 << 40; // SCHED_FLAG_KESTREL_HINT
const KEEP_POLICY: u64 = 0x08;
const KEEP_PARAMS: u64 = 0x10;

const SchedAttrExt = extern struct {
    size: u32,
    sched_policy: u32,
    sched_flags: u64,
    sched_nice: i32,
    sched_priority: u32,
    sched_runtime: u64,
    sched_deadline: u64,
    sched_period: u64,
    sched_util_min: u32,
    sched_util_max: u32,
    sched_ext_hint: u32,
};

/// Set the hint on one task. No-op (the syscall fails) on a stock kernel.
pub fn setTid(tid: std.os.linux.pid_t, hint: u32) void {
    if (builtin.os.tag != .linux) return;
    var attr = SchedAttrExt{
        .size = @sizeOf(SchedAttrExt),
        .sched_policy = 0,
        .sched_flags = FLAG | KEEP_POLICY | KEEP_PARAMS,
        .sched_nice = 0,
        .sched_priority = 0,
        .sched_runtime = 0,
        .sched_deadline = 0,
        .sched_period = 0,
        .sched_util_min = 0,
        .sched_util_max = 0,
        .sched_ext_hint = hint,
    };
    _ = std.os.linux.syscall3(
        .sched_setattr,
        @as(usize, @bitCast(@as(isize, tid))),
        @intFromPtr(&attr),
        0,
    );
}

/// Set the hint on the calling thread. Threads spawned after a
/// setProcess() call are not covered; call this from the thread entrypoint.
pub fn setCurrentThread(hint: u32) void {
    if (builtin.os.tag != .linux) return;
    setTid(std.os.linux.gettid(), hint);
}

/// Set the hint on the process' main thread. Threads created later are not
/// covered; the renderer and IO threads call setCurrentThread() themselves.
pub fn setProcess(hint: u32) void {
    if (builtin.os.tag != .linux) return;
    setTid(std.os.linux.getpid(), hint);
}
