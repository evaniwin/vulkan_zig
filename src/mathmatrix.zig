pub fn lookat(eye: [3]f32, center: [3]f32, Up: [3]f32) [4][4]f32 {
    const front = vec3normalize(vec3sub(center, eye));
    const right = vec3normalize(vec3cross(front, Up));
    const up = vec3normalize(vec3cross(right, front));
    return .{
        .{ right[0], right[1], right[2], -vec3dot(right, eye) },
        .{ up[0], up[1], up[2], -vec3dot(up, eye) },
        .{ -front[0], -front[1], -front[2], vec3dot(front, eye) },
        .{ 0, 0, 0, 1 },
    };
}

pub fn perspective(fov: f32, width: f32, height: f32, near: f32, far: f32) [4][4]f32 {
    const focallength = 1 / std.math.tan(fov / 2);
    const aspectratio = width / height;
    return .{
        .{ focallength / aspectratio, 0, 0, 0 },
        .{ 0, -focallength, 0, 0 },
        .{ 0, 0, far / (near - far), near * far / (near - far) },
        .{ 0, 0, -1, 0 },
    };
}

pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) [4][4]f32 {
    return .{
        .{ 2.0 / (right - left), 0.0, 0.0, 0.0 },
        .{ 0.0, 2.0 / (top - bottom), 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0 / (far - near), 0.0 },
        .{ -(right + left) / (right - left), -(top + bottom) / (top - bottom), -near / (far - near), 1.0 },
    };
}
pub fn rotate(angle: f32, axis: [3]f32) [4][4]f32 {
    const cosa = std.math.cos(angle);
    const sina = std.math.sin(angle);
    const naxis = vec3normalize(axis);
    const rotatemat: [4][4]f32 = .{
        .{ cosa + naxis[0] * naxis[0] * (1 - cosa), naxis[0] * naxis[1] * (1 - cosa) - naxis[2] * sina, naxis[0] * naxis[2] * (1 - cosa) + naxis[1] * sina, 0 },
        .{ naxis[1] * naxis[0] * (1 - cosa) + naxis[2] * sina, cosa + naxis[1] * naxis[1] * (1 - cosa), naxis[1] * naxis[2] * (1 - cosa) - naxis[0] * sina, 0 },
        .{ naxis[2] * naxis[0] * (1 - cosa) - naxis[1] * sina, naxis[2] * naxis[1] * (1 - cosa) + naxis[0] * sina, cosa + naxis[2] * naxis[2] * (1 - cosa), 0 },
        .{ 0, 0, 0, 1 },
    };

    return rotatemat;
}

///AxB
fn mat4x4multi(a: [4][4]f32, b: [4][4]f32) [4][4]f32 {
    return .{
        .{
            a[0][0] * b[0][0] + a[0][1] * b[1][0] + a[0][2] * b[2][0] + a[0][3] * b[3][0],
            a[0][0] * b[0][1] + a[0][1] * b[1][1] + a[0][2] * b[2][1] + a[0][3] * b[3][1],
            a[0][0] * b[0][2] + a[0][1] * b[1][2] + a[0][2] * b[2][2] + a[0][3] * b[3][2],
            a[0][0] * b[0][3] + a[0][1] * b[1][3] + a[0][2] * b[2][3] + a[0][3] * b[3][3],
        },
        .{
            a[1][0] * b[0][0] + a[1][1] * b[1][0] + a[1][2] * b[2][0] + a[1][3] * b[3][0],
            a[1][0] * b[0][1] + a[1][1] * b[1][1] + a[1][2] * b[2][1] + a[1][3] * b[3][1],
            a[1][0] * b[0][2] + a[1][1] * b[1][2] + a[1][2] * b[2][2] + a[1][3] * b[3][2],
            a[1][0] * b[0][3] + a[1][1] * b[1][3] + a[1][2] * b[2][3] + a[1][3] * b[3][3],
        },
        .{
            a[2][0] * b[0][0] + a[2][1] * b[1][0] + a[2][2] * b[2][0] + a[2][3] * b[3][0],
            a[2][0] * b[0][1] + a[2][1] * b[1][1] + a[2][2] * b[2][1] + a[2][3] * b[3][1],
            a[2][0] * b[0][2] + a[2][1] * b[1][2] + a[2][2] * b[2][2] + a[2][3] * b[3][2],
            a[2][0] * b[0][3] + a[2][1] * b[1][3] + a[2][2] * b[2][3] + a[2][3] * b[3][3],
        },
        .{
            a[3][0] * b[0][0] + a[3][1] * b[1][0] + a[3][2] * b[2][0] + a[3][3] * b[3][0],
            a[3][0] * b[0][1] + a[3][1] * b[1][1] + a[3][2] * b[2][1] + a[3][3] * b[3][1],
            a[3][0] * b[0][2] + a[3][1] * b[1][2] + a[3][2] * b[2][2] + a[3][3] * b[3][2],
            a[3][0] * b[0][3] + a[3][1] * b[1][3] + a[3][2] * b[2][3] + a[3][3] * b[3][3],
        },
    };
}

///a.b
fn vec3dot(a: [3]f32, b: [3]f32) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}
fn vec2dot(a: [2]f32, b: [2]f32) f32 {
    return a[0] * b[0] + a[1] * b[1];
}
///axb
fn vec3cross(a: [3]f32, b: [3]f32) [3]f32 {
    const x = a[1] * b[2] - a[2] * b[1];
    const y = a[2] * b[0] - a[0] * b[2];
    const z = a[0] * b[1] - a[1] * b[0];

    return .{ x, y, z };
}
///|vect|
fn vec3normalize(vect: [3]f32) [3]f32 {
    const magnitude = std.math.sqrt(vec3dot(vect, vect));
    if (magnitude == 0.0) return .{ 0.0, 0.0, 0.0 };
    return .{ vect[0] / magnitude, vect[1] / magnitude, vect[2] / magnitude };
}
pub fn vec2normalize(vect: [2]f32) [2]f32 {
    const magnitude = std.math.sqrt(vec2dot(vect, vect));
    if (magnitude == 0.0) return .{ 0.0, 0.0 };
    return .{ vect[0] / magnitude, vect[1] / magnitude };
}
///a+b
fn vec3add(a: [3]f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = a[i] + b[i];
    }
    return result;
}
///a-b
fn vec3sub(a: [3]f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = a[i] - b[i];
    }
    return result;
}
///a*b
fn vec3multi(a: [3]f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = a[i] * b[i];
    }
    return result;
}
///a/b
fn vec3div(a: [3]f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = a[i] / b[i];
    }
    return result;
}
///c*b
fn vec3constmulti(c: f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = c * b[i];
    }
    return result;
}
///c/b
fn vec3constdiv(c: f32, b: [3]f32) [3]f32 {
    var result: [3]f32 = undefined;
    for (0..3) |i| {
        result[i] = c / b[i];
    }
    return result;
}
test mat4x4multi {
    const identity: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    const zero: [4][4]f32 = .{
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    };
    const A: [4][4]f32 = .{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    };
    const B: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, -1, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    const AB: [4][4]f32 = .{
        .{ 1, 2, 1, 4 },
        .{ 5, 6, 1, 8 },
        .{ 9, 10, 1, 12 },
        .{ 13, 14, 1, 16 },
    };
    const Binv: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 1, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };

    const t1 = mat4x4multi(identity, zero);
    const t2 = mat4x4multi(B, zero);
    const t3 = mat4x4multi(identity, B);
    const t4 = mat4x4multi(A, zero);
    const t5 = mat4x4multi(identity, A);
    const t6 = mat4x4multi(A, B);
    const t7 = mat4x4multi(B, Binv);
    const t8 = mat4x4multi(Binv, B);
    for (0..4) |i| {
        for (0..4) |j| {
            try testing.expectEqual(t1[i][j], zero[i][j]);
            try testing.expectEqual(t2[i][j], zero[i][j]);
            try testing.expectEqual(t3[i][j], B[i][j]);
            try testing.expectEqual(t4[i][j], zero[i][j]);
            try testing.expectEqual(t5[i][j], A[i][j]);
            try testing.expectEqual(t6[i][j], AB[i][j]);
            try testing.expectEqual(t7[i][j], identity[i][j]);
            try testing.expectEqual(t8[i][j], identity[i][j]);
        }
    }
}
const testing = std.testing;
const std = @import("std");
