"""Cuts the game's typeface down to the characters the game actually uses.

    python tools/subset_font.py

Reads fonts/src/YujiSyuku-Regular.ttf (the full font, 8 MB) and writes
fonts/YujiSyuku-Regular.ttf with only the glyphs that appear in scripts/*.gd, plus Latin
letters with macrons and common punctuation. Run it again after adding text: in the web
build there is no system font to fall back on, so a missing character shows as a blank.
Needs fonttools (pip install fonttools).
"""
import glob, os, sys
from fontTools import subset
from fontTools.ttLib import TTFont

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = os.path.join(root, 'fonts', 'src', 'YujiSyuku-Regular.ttf')
dst = os.path.join(root, 'fonts', 'YujiSyuku-Regular.ttf')

chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set(chr(c) for c in range(0xA0, 0x180))          # Latin-1 and Latin Extended-A (macron vowels)
chars |= set('—–‘’“”…·・、。「」『』〈〉（）！？：；％→←↑↓↻〜ー々')
chars |= set('0123456789一二三四五六七八九十百千万')
for path in glob.glob(os.path.join(root, 'scripts', '*.gd')):
    chars |= set(open(path, encoding='utf-8').read())
chars = {c for c in chars if c >= ' '}

font = TTFont(src)
have = set(font.getBestCmap().keys())
missing = sorted(c for c in chars if ord(c) not in have and ord(c) > 0x7F)
opts = subset.Options()
opts.layout_features = ['*']
opts.name_IDs = ['*']
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(unicodes=[ord(c) for c in chars])
sub.subset(font)
font.save(dst)
print('%d characters kept; %.1f MB -> %.2f MB' % (len(chars), os.path.getsize(src) / 1e6, os.path.getsize(dst) / 1e6))
if missing:
    print('not in this typeface (the system font, if any, will draw them): ' + ''.join(missing))
