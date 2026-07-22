#!/usr/bin/env python3
"""生成 App 图标：玫瑰渐变底 + 周期环弧线 + 白色水滴。纯标准库，无需 PIL。"""
import math
import struct
import zlib

SIZE = 1024
SS = 2  # 每像素 2x2 超采样抗锯齿

# 背景渐变色（左上 → 右下）
BG_TOP = (240.0, 110.0, 140.0)
BG_BOT = (190.0, 45.0, 85.0)

# 周期环
CX = CY = 512.0
RING_R, RING_HALF_W = 400.0, 17.0
GAP_LO, GAP_HI = 225.0, 315.0   # 缺口角度区间（度）
DOT_ANGLE = math.radians(280.0)  # 缺口中的"今天"圆点
DOT_X = CX + RING_R * math.cos(DOT_ANGLE)
DOT_Y = CY + RING_R * math.sin(DOT_ANGLE)
DOT_R = 34.0

# 水滴：底部圆 + 顶点切线三角
DCX, DCY, DR = 512.0, 640.0, 250.0
APEX = (512.0, 250.0)
_dx, _dy = DCX - APEX[0], DCY - APEX[1]
_d = math.hypot(_dx, _dy)
_l = math.sqrt(_d * _d - DR * DR)
_ang = math.atan2(_dy, _dx)
_half = math.asin(DR / _d)
T1 = (APEX[0] + _l * math.cos(_ang - _half), APEX[1] + _l * math.sin(_ang - _half))
T2 = (APEX[0] + _l * math.cos(_ang + _half), APEX[1] + _l * math.sin(_ang + _half))

# 水滴内高光椭圆
HL_CX, HL_CY, HL_RX, HL_RY = 420.0, 565.0, 60.0, 85.0


def in_triangle(px, py, a, b, c):
    def cross(o, u, v):
        return (u[0] - o[0]) * (v[1] - o[1]) - (u[1] - o[1]) * (v[0] - o[0])
    d1 = cross(a, b, (px, py))
    d2 = cross(b, c, (px, py))
    d3 = cross(c, a, (px, py))
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def sample(x, y):
    t = (x + y) / (2 * SIZE)
    r = BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t
    g = BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t
    b = BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t

    # 环形弧线（带缺口），白色 alpha 0.35
    ddx, ddy = x - CX, y - CY
    dist = math.hypot(ddx, ddy)
    if abs(dist - RING_R) <= RING_HALF_W:
        deg = math.degrees(math.atan2(ddy, ddx)) % 360.0
        if not (GAP_LO < deg < GAP_HI):
            a = 0.35
            r = r * (1 - a) + 255 * a
            g = g * (1 - a) + 255 * a
            b = b * (1 - a) + 255 * a

    # "今天"圆点，白色 alpha 0.9
    if math.hypot(x - DOT_X, y - DOT_Y) <= DOT_R:
        a = 0.9
        r = r * (1 - a) + 255 * a
        g = g * (1 - a) + 255 * a
        b = b * (1 - a) + 255 * a

    # 水滴：圆 ∪ 切线三角，纯白
    in_drop = math.hypot(x - DCX, y - DCY) <= DR or in_triangle(x, y, APEX, T1, T2)
    if in_drop:
        r = g = b = 255.0
        # 高光：淡玫瑰
        hx = (x - HL_CX) / HL_RX
        hy = (y - HL_CY) / HL_RY
        if hx * hx + hy * hy <= 1.0:
            a = 0.22
            r = r * (1 - a) + 224 * a
            g = g * (1 - a) + 82 * a
            b = b * (1 - a) + 110 * a

    return r, g, b


def main():
    rows = []
    step = 1.0 / SS
    for py in range(SIZE):
        row = bytearray()
        row.append(0)  # PNG filter: none
        for px in range(SIZE):
            r = g = b = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    sr, sg, sb = sample(px + (sx + 0.5) * step, py + (sy + 0.5) * step)
                    r += sr; g += sg; b += sb
            n = SS * SS
            row += bytes((min(255, int(r / n + 0.5)),
                          min(255, int(g / n + 0.5)),
                          min(255, int(b / n + 0.5))))
        rows.append(bytes(row))

    raw = b"".join(rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))

    out = "CycleTracker/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    with open(out, "wb") as f:
        f.write(png)
    print(f"icon written: {out} ({len(png)} bytes)")


if __name__ == "__main__":
    main()
