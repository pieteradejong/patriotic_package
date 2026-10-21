#!/usr/bin/env bash
# Rebuilds the two header images (docs/DECISIONS.md #15):
#   src/assets/header-flag.webp   a waving, shaded US flag drawn here (no source image)
#   src/assets/header-eagle.webp  a USFWS eagle photo, cut out with macOS Vision
# Needs macOS 14+ (Vision), ImageMagick 7, cwebp, python3, swift. Work files go to a temp dir.
set -euo pipefail

cd "$(dirname "$0")/../.."
here=scripts/header
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

src_url='https://upload.wikimedia.org/wikipedia/commons/a/a3/Bald_eagle_in_flight_%2851080613667%29.jpg'

# Flag: 13 stripes, a canton seven stripes tall, 50 stars, at 2400x1000.
python3 - "$work/flag.svg" <<'EOF'
import math, sys
W, H = 2400, 1000
s = H / 13
cw, ch = W * 0.40, s * 7
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">',
       f'<rect width="{W}" height="{H}" fill="#f4efe2"/>']
for i in range(0, 13, 2):
    out.append(f'<rect y="{i*s:.2f}" width="{W}" height="{s:.2f}" fill="#b31942"/>')
out.append(f'<rect width="{cw:.2f}" height="{ch:.2f}" fill="#0a3161"/>')
r = ch * 0.0616
for row in range(9):
    for c in range(6 if row % 2 == 0 else 5):
        x, y = cw / 12 * (2 * c + 1 + row % 2), ch / 10 * (row + 1)
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = r if k % 2 == 0 else r * 0.382
            pts.append(f'{x + rr*math.cos(a):.1f},{y + rr*math.sin(a):.1f}')
        out.append(f'<polygon points="{" ".join(pts)}" fill="#f4efe2"/>')
out.append('</svg>')
open(sys.argv[1], 'w').write('\n'.join(out))
EOF

# Folds: two sine waves. One map shifts the stripes up and down, the other is the
# light falling on the folds (its slope). Both are drawn small and scaled up smooth.
fold='(0.6*sin(2*pi*(i/w*2.3+j/h*0.35))+0.4*sin(2*pi*(i/w*3.9-j/h*0.25)+1.3))'
slope='(0.6*2.3*cos(2*pi*(i/w*2.3+j/h*0.35))+0.4*3.9*cos(2*pi*(i/w*3.9-j/h*0.25)+1.3))/3.0'
magick -density 96 "$work/flag.svg" -depth 8 -colorspace sRGB PNG24:"$work/flat.png"
magick -size 600x250 xc:gray -fx "0.5+0.5*$fold" -resize '2400x1000!' "$work/displace.png"
magick -size 600x250 xc:gray -fx "0.5+0.32*$slope" -resize '2400x1000!' "$work/shade.png"
magick -size 600x250 plasma:gray50-gray50 -colorspace gray -blur 0x6 -resize '2400x1000!' -level 30%,70% "$work/mottle.png"
magick -size 2400x1000 xc:gray +noise Gaussian -colorspace gray -blur 0x1.2 -level 35%,65% "$work/grain.png"
magick -size 2400x1000 radial-gradient:white-gray30 -colorspace gray "$work/vignette.png"
magick "$work/flat.png" "$work/displace.png" -compose displace -define compose:args=0x36 -composite PNG24:"$work/waved.png"
# Grayscale maps are combined with -fx: compose overlay/softlight treat a gray map as one channel.
magick "$work/shade.png" "$work/mottle.png" "$work/grain.png" "$work/vignette.png" \
	-fx '(0.55+0.9*u[0]) * (0.85+0.3*u[1]) * (0.93+0.14*u[2]) * (0.25+0.75*u[3])' -colorspace gray "$work/light.png"
magick "$work/waved.png" "$work/light.png" -fx 'u*v.r' -modulate 100,78 \
	-resize 2000x -crop 2000x720+0+50 +repage PNG24:"$work/flag.png"
cwebp -quiet -q 72 -m 6 "$work/flag.png" -o src/assets/header-flag.webp

# Eagle: cut out with Vision. Seen from below, its underside is lit blue by the sky, so the
# blue key is applied only near the outline (a band about 10px wide at full size) plus wherever
# a pixel is both bright and strongly blue (sky between the wingtip feathers). Then the mask
# is eroded a little, bluish pixels are pulled halfway to grey, and the bird is turned 14°
# counter-clockwise so its wings are level.
curl -fsSL -A 'patriot-package header build' -o "$work/eagle.jpg" "$src_url"
swift "$here/lift.swift" "$work/eagle.jpg" "$work/cut.png"
magick "$work/cut.png" -alpha extract -threshold 50% -morphology Erode Disk:10 -blur 0x3 "$work/interior.png"
magick "$work/cut.png" "$work/interior.png" -channel A \
	-fx 'u.a*(1-(1-v.r)*min(1,max(0,(u.b-u.r-0.06)*5)))*(1-min(1,max(0,(u.b-u.r-0.25)*10))*min(1,max(0,(u.b-0.55)*8)))' +channel \
	\( +clone -alpha extract -morphology Erode Disk:1.5 -blur 0x0.8 \) -compose CopyOpacity -composite \
	-channel RGB -fx 'b>r ? 0.5*u+0.5*(0.3*r+0.59*g+0.11*b) : u' +channel \
	-background none -rotate -14 -trim +repage -resize 1600x PNG32:"$work/eagle.png"
cwebp -quiet -q 82 -alpha_q 90 -m 6 "$work/eagle.png" -o src/assets/header-eagle.webp

magick identify src/assets/header-flag.webp src/assets/header-eagle.webp
