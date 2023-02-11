module sidero.image.manipulation.geometric;
import sidero.image.defs;
import sidero.colorimetry;
import sidero.base.allocators;
import sidero.base.errors;

export @safe nothrow @nogc:

/// Translate and expand/shrink
Result!Image translate(return scope Image source, size_t offsetX, size_t offsetY, ptrdiff_t deltaWidth, ptrdiff_t deltaHeight,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {
    if (source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));

    const newWidth1 = offsetX + source.width, newHeight1 = offsetY + source.height;

    if (newWidth1 < deltaWidth || newHeight1 < deltaHeight)
        return typeof(return)(MalformedInputException("New size calculation cannot be negative when applying delta sizes"));

    const newWidth = newWidth1 + deltaWidth, newHeight = newHeight1 + deltaHeight;
    const newWidth2  = newWidth1 > newWidth ? newWidth : newWidth1, newHeight2 = newHeight1 > newHeight ? newHeight : newHeight1;

    if (colorSpace.isNull)
        colorSpace = source.colorSpace;

    Image ret = Image(colorSpace, newWidth, newHeight, allocator);

    {
        // ..........
        // ...|--|...
        // ...|  |...
        // ...|--|...
        // ..........

        foreach (y; 0 .. offsetY) {
            foreach (x; 0 .. newWidth) {
                auto dest = ret[x, y];
                if (!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if (!got)
                    return typeof(return)(got.getError());
            }
        }

        foreach (y; offsetY .. newHeight) {
            foreach (x; 0 .. offsetX) {
                auto dest = ret[x, y];
                if (!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if (!got)
                    return typeof(return)(got.getError());
            }

            foreach (x; newWidth1 .. newWidth) {
                auto dest = ret[x, y];
                if (!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if (!got)
                    return typeof(return)(got.getError());
            }
        }

        foreach (y; newHeight1 .. newHeight) {
            foreach (x; 0 .. newWidth) {
                auto dest = ret[x, y];
                if (!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if (!got)
                    return typeof(return)(got.getError());
            }
        }
    }

    {
        foreach(y; offsetY .. newHeight2) {
            foreach(x; offsetX .. newWidth2) {
                auto dest = ret[x, y];
                if (!dest)
                    return typeof(return)(dest.getError());

                auto src = source[x - offsetX, y - offsetY];
                if (!src)
                    return typeof(return)(dest.getError());

                auto got = src.convertInto(dest);
                if (!got)
                    return typeof(return)(got.getError());
            }
        }
    }

    return typeof(return)(ret);
}

/// Interpolated scaling
Result!Image scale(scope Image source, double xScale, double yScale, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    // const second = coord - floor(coord), first = 1 - first;
    assert(0);
}

///
Result!Image rotate(scope Image source, double angle, size_t centerX, size_t centerY,
    scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
    return scope RCAllocator allocator = RCAllocator.init) {

    // new_width = abs(old_width * cos(angle)) + abs(old_height * sin(angle))
    // new_height = abs(old_height * cos(angle)) + abs(old_width * sin(angle))

    // use three shear method: https://www.sciencedirect.com/science/article/pii/S1077316997904202 https://datagenetics.com/blog/august32013/index.html
    assert(0);
}
