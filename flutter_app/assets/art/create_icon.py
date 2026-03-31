import struct, zlib, os
w, h = 128, 128
def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
raw = b''
for y in range(h):
    raw += b'\x00' + bytes([26, 26, 46, 255]) * w
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw))
png += chunk(b'IEND', b'')
script_dir = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(script_dir, 'icon.png')
with open(path, 'wb') as f:
    f.write(png)
print(f'Icon created: {len(png)} bytes at {path}')
