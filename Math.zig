const std = @import("std");
const LARGE_INTEGER = i64;

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *LARGE_INTEGER) callconv(.winapi) bool;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *LARGE_INTEGER) callconv(.winapi) bool;

fn getTime() i64 {
    var counter: LARGE_INTEGER = undefined;
    _ = QueryPerformanceCounter(&counter);
    return counter;
}

fn getFrequency() i64 {
    var freq: LARGE_INTEGER = undefined;
    _ = QueryPerformanceFrequency(&freq);
    return freq;
}

pub inline fn add(comptime T: type, Left_Op: T, Right_Op: T) T {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => (Left_Op + Right_Op),
        .float, .comptime_float => (Left_Op + Right_Op),
        .vector => (Left_Op + Right_Op),
        .array => |info| {
            const V = @Vector(info.len, info.child);
            const va: V = Left_Op;
            const vb: V = Right_Op;
            return @as(T, va + vb);
        },
        else => @compileError("Unsupported data type: " ++ @typeName(T)),
    };
}

fn ReduceChild(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .array  => |info| info.child,
        .vector => |info| info.child,
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    };
}

pub fn reduce_add(comptime T: type, Left_Op: T) ReduceChild(T) {
    return switch (@typeInfo(T)) {
        .vector => (@reduce(.Add, Left_Op)),
        .array => |info| {
            switch (@typeInfo(info.child)) {
                .vector, .array => @compileError("Unsupported Child-data type: " ++ @typeName(T)),
                else => {},
            }
            var result: info.child = 0;
            var index: usize = 0;
            while (index < info.len) : (index += 1) {
                result = add(info.child, result, Left_Op[index]);
            }
            return result;
        },
        else => @compileError("Unsupported data type: " ++ @typeName(T)),
    };
}

pub inline fn add_p(comptime T: type, Left_Op: T, Right_Op: T) T {
  var result: T = undefined;
  var j: usize = 0;
  while (j < @typeInfo(T).array.len) : (j += 1) {
      result[j] = Left_Op[j] + Right_Op[j];
  }
  return result;
}

pub fn main() !void {
    const iterations = 1_000_000;
    const size = 100;

    var a: [size]i32 = undefined;
    var b: [size]i32 = undefined;

    var k: usize = 0;
    const seed: i32 = @truncate(getTime());
    while (k < size) : (k += 1) {
        a[k] = @intCast(@abs(@as(i32, @intCast(k)) * 3 + 7 + (seed >> 1)));
        b[k] = @intCast(@abs(@as(i32, @intCast(k)) * 5 + 13 + (seed >> 1)));
    }

    const freq = getFrequency();

    // benchmark add genérico
    var sink1: [100] i32 = undefined;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
    sink1 = add([100]i32, a, b);
    }
    i = 0;
    const t1_start = getTime();
    var a_ptr: *volatile [size]i32 = &a;
    var b_ptr: *volatile [size]i32 = &b;

    while (i < iterations) : (i += 1) {
        sink1 = add([size]i32, a_ptr.*, b_ptr.*);
    }
    var t1 = @divTrunc((getTime() - t1_start) * 1_000_000_000, freq);
    t1 = ~(~t1);

    // benchmark add puro
    var sink2: [size]i32 = undefined;
    a_ptr = &a;
    b_ptr = &b;
    i = 0;
    const t2_start = getTime();
    const V = @Vector(size, i32);
    while (i < iterations) : (i += 1) {

        const va: V = a_ptr.*;
        const vb: V = b_ptr.*;
        sink2 = @as([100]i32, va + vb);
    }
    const t2 = @divTrunc((getTime() - t2_start) * 1_000_000_000, freq);

std.debug.print("generico[0]       :      {}\n", .{sink1[0]});
std.debug.print("puro[0]           :      {}\n", .{sink2[0]});

std.debug.print("reduce generico[0]:      {}\n", .{reduce_add([size]i32, sink1)});
std.debug.print("reduce puro[0]    :      {}\n", .{reduce_add([size]i32, sink2)});
std.debug.print("generico          :      {}ms {}us\n", .{ @divTrunc(t1, 1_000_000), @divTrunc(@mod(t1, 1_000_000), 1_000) });
std.debug.print("puro              :      {}ms {}us\n", .{ @divTrunc(t2, 1_000_000), @divTrunc(@mod(t2, 1_000_000), 1_000) });

}

// zig build-exe -O ReleaseFast Math.zig