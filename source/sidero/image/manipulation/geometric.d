module sidero.image.manipulation.geometric;
import sidero.image.defs;
import sidero.colorimetry;
import sidero.base.allocators;
import sidero.base.errors;

export @safe nothrow @nogc:

/// Translate and expand/shrink
Result!Image translate(return scope Image source, size_t offsetX, size_t offsetY, size_t addToWidth = 0, size_t addToHeight = 0,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {
    if (source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));

    const newWidth1 = offsetX + source.width, newHeight1 = offsetY + source.height;
    const newWidth = newWidth1 + addToWidth, newHeight = newHeight1 + addToHeight;
    const newWidth2 = newWidth1 > newWidth ? newWidth : newWidth1, newHeight2 = newHeight1 > newHeight ? newHeight : newHeight1;

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
        foreach (y; offsetY .. newHeight2) {
            foreach (x; offsetX .. newWidth2) {
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

/// Uses linear interpolated scaling
Result!Image scale(scope Image source, double xScale, double yScale, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.math.utils : floor;

    if (source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    if (colorSpace.isNull)
        colorSpace = source.colorSpace;

    const newWidth = cast(ptrdiff_t)(source.width * xScale), newHeight = cast(ptrdiff_t)(source.height * yScale);

    if (newWidth <= 0 || newHeight <= 0)
        return typeof(return)(MalformedInputException("New size calculation cannot be below or equal to zero"));

    Image ret = Image(colorSpace, cast(size_t)newWidth, cast(size_t)newHeight, allocator);

    void fillInAuxillary(scope ref Pixel output, scope ref PixelReference firstPixel, scope ref PixelReference secondPixel,
            double ratio1, double ratio2) {
        foreach (c; colorSpace.channels) {
            if (!c.isAuxillary || c.blendMode == ChannelSpecification.BlendMode.ExactOrDefaultOnly)
                continue;

            bool gotOne;
            double temp = 0;

            {
                auto got2 = firstPixel.channel01(c.name);
                if (got2) {
                    temp += got2.get * ratio1;
                    gotOne = true;
                }
            }

            {
                auto got2 = secondPixel.channel01(c.name);
                if (got2) {
                    temp += got2.get * ratio2;
                    gotOne = true;
                }
            }

            if (gotOne) {
                output.channel01(c.name, temp);
            }
        }
    }

    foreach (y; 0 .. newHeight) {
        foreach (x; 0 .. newWidth) {
            auto dest = ret[x, y];
            if (!dest)
                return typeof(return)(dest.getError());

            const src1X = x / xScale, src2X = (x + 1) / xScale, src1Y = y / yScale, src2Y = (y + 1) / yScale;
            const secondRatio = ((src1X - floor(src1X)) + (src1Y - floor(src1Y))) / 2, firstRatio = 1 - secondRatio;

            auto firstPixel = source[cast(size_t)src1X, cast(size_t)src1Y], secondPixel = source[cast(size_t)src2X, cast(size_t)src2Y];
            if (!firstPixel)
                continue; // ughhhh what?

            {
                CIEXYZSample temp;

                {
                    auto got = firstPixel.asXYZ;
                    assert(got);

                    temp = got.get;
                    temp.sample *= firstRatio;
                }

                {
                    auto got = firstPixel.asXYZ;
                    assert(got);

                    temp.sample += got.get.sample * secondRatio;
                }

                dest = temp;
            }

            fillInAuxillary(dest, firstPixel, secondPixel, firstRatio, secondRatio);
        }
    }

    assert(0);
}

///
Result!Image rotate(scope Image source, double angle, size_t centerX, size_t centerY, scope Pixel fallbackColor = Pixel.init,
        return scope ColorSpace colorSpace = ColorSpace.init, return scope RCAllocator allocator = RCAllocator.init) {

    // new_width = abs(old_width * cos(angle)) + abs(old_height * sin(angle))
    // new_height = abs(old_height * cos(angle)) + abs(old_width * sin(angle))

    // use three shear method: https://www.sciencedirect.com/science/article/pii/S1077316997904202 https://datagenetics.com/blog/august32013/index.html
    assert(0);
}
