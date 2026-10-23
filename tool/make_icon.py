"""Vẽ icon ứng dụng theo phong cách 'Hồ sơ lưu trữ': giấy ngà, bìa hồ sơ manila, dấu son."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random, os, glob
S = 1024
PAPER, INK, MANILA, EDGE, CIN = (241,236,224), (27,42,65), (222,196,146), (176,146,96), (178,46,32)
im = Image.new('RGB', (S, S), PAPER); d = ImageDraw.Draw(im)
random.seed(7)
for _ in range(60000):
    x, y = random.randrange(S), random.randrange(S); v = random.randint(-10, 6)
    p = im.getpixel((x, y)); im.putpixel((x, y), tuple(max(0, min(255, c + v)) for c in p))
# back folder + tab
d.rectangle([170, 300, 470, 380], fill=EDGE)
d.rectangle([170, 350, 854, 800], fill=EDGE)
# paper sheet peeking
d.rectangle([215, 330, 810, 760], fill=(250,247,239), outline=(205,198,182), width=3)
for y in range(390, 520, 34): d.line([255, y, 760, y], fill=(190,200,214), width=3)
# front folder flap
d.polygon([(150, 470), (874, 470), (854, 830), (170, 830)], fill=MANILA)
d.line([(150, 470), (874, 470)], fill=EDGE, width=6)
# ink label strip
d.rectangle([230, 560, 560, 600], fill=INK)
d.rectangle([230, 630, 470, 646], fill=(150,128,90))
# cinnabar seal, rotated
seal = Image.new('RGBA', (300, 300), (0,0,0,0)); sd = ImageDraw.Draw(seal)
sd.rectangle([20, 20, 280, 280], outline=CIN, width=16); sd.rectangle([46, 46, 254, 254], outline=CIN, width=6)
try: f = ImageFont.truetype('assets/fonts/Lora.ttf', 150)
except Exception: f = ImageFont.load_default()
sd.text((150, 152), 'TG', font=f, fill=CIN, anchor='mm')
seal = seal.rotate(-9, resample=Image.BICUBIC, expand=True)
im.paste(seal, (560, 520), seal)
im.save('assets/icon.png')
for p in glob.glob('android/app/src/main/res/mipmap-*/ic_launcher.png'):
    n = Image.open(p).size[0]; im.resize((n, n), Image.LANCZOS).save(p)
for p in glob.glob('ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png'):
    n = Image.open(p).size[0]; im.resize((n, n), Image.LANCZOS).save(p)
