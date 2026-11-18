#!/usr/bin/env python3

import argparse
import os
import tempfile

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem


def unicode_cmap(font):
    """Return a combined mapping of Unicode codepoints to glyph names."""
    result = {}
    for table in font["cmap"].tables:
        if table.isUnicode():
            result.update(table.cmap)
    return result


def main():
    parser = argparse.ArgumentParser(description="Merge an extra font into a base font. The base font's metrics and hinting are used.")
    parser.add_argument("base", help="Base font")
    parser.add_argument("extra", help="Extra font whose glyphs are added")
    parser.add_argument("-o", "--output", default="merged.ttf", help="Output file (default: merged.ttf)")
    args = parser.parse_args()

    base_upem = TTFont(args.base)["head"].unitsPerEm
    extra = TTFont(args.extra)
    extra_upem = extra["head"].unitsPerEm

    extra_path = args.extra
    temp_paths = []

    try:
        if extra_upem != base_upem:
            print(f"Scaling '{args.extra}' from {extra_upem} to {base_upem} units per em")
            scale_upem(extra, base_upem)

            fd, extra_path = tempfile.mkstemp(suffix=".ttf")
            os.close(fd)
            temp_paths.append(extra_path)
            extra.save(extra_path)

        base = TTFont(args.base)
        scaled_extra = TTFont(extra_path)

        base_cmap = unicode_cmap(base)
        extra_cmap = unicode_cmap(scaled_extra)

        # Remove base glyphs mapped to codepoints that the extra font maps.
        overlapping_codepoints = set(base_cmap) & set(extra_cmap)
        drop_glyphs = {base_cmap[cp] for cp in overlapping_codepoints}

        # Also remove identically named glyphs, including glyphs not in cmap.
        drop_glyphs.update(set(base.getGlyphOrder()) & set(scaled_extra.getGlyphOrder()))

        keep_glyphs = set(base.getGlyphOrder()) - drop_glyphs
        keep_glyphs.add(".notdef")

        print(f"Dropping {len(drop_glyphs)} base glyphs for {len(overlapping_codepoints)} overlapping codepoints")

        options = subset.Options()
        options.glyph_names = True
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(glyphs=sorted(keep_glyphs))
        subsetter.subset(base)

        fd, base_path = tempfile.mkstemp(suffix=".ttf")
        os.close(fd)
        temp_paths.append(base_path)
        base.save(base_path)

        merged = Merger().merge([base_path, extra_path])
        # Set timestamps to a fixed value for reproducible output
        merged.recalcTimestamp = False
        merged["head"].created = 0
        merged["head"].modified = 0
        merged.save(args.output)
        print(f"Merged into '{args.output}'")

    finally:
        for path in temp_paths:
            if os.path.exists(path):
                os.remove(path)


if __name__ == "__main__":
    main()
