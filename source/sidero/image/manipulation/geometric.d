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
    if(source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));

    const newWidth1 = offsetX + source.width, newHeight1 = offsetY + source.height;
    const newWidth = newWidth1 + addToWidth, newHeight = newHeight1 + addToHeight;
    const newWidth2 = newWidth1 > newWidth ? newWidth : newWidth1, newHeight2 = newHeight1 > newHeight ? newHeight : newHeight1;

    if(colorSpace.isNull)
        colorSpace = source.colorSpace;

    Image ret = Image(colorSpace, newWidth, newHeight, allocator);

    {
        // ..........
        // ...|--|...
        // ...|  |...
        // ...|--|...
        // ..........

        foreach(y; 0 .. offsetY) {
            foreach(x; 0 .. newWidth) {
                auto dest = ret[x, y];
                if(!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if(!got)
                    return typeof(return)(got.getError());
            }
        }

        foreach(y; offsetY .. newHeight) {
            foreach(x; 0 .. offsetX) {
                auto dest = ret[x, y];
                if(!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if(!got)
                    return typeof(return)(got.getError());
            }

            foreach(x; newWidth1 .. newWidth) {
                auto dest = ret[x, y];
                if(!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if(!got)
                    return typeof(return)(got.getError());
            }
        }

        foreach(y; newHeight1 .. newHeight) {
            foreach(x; 0 .. newWidth) {
                auto dest = ret[x, y];
                if(!dest)
                    return typeof(return)(dest.getError());

                auto got = fallbackColor.convertInto(dest);
                if(!got)
                    return typeof(return)(got.getError());
            }
        }
    }

    {
        foreach(y; offsetY .. newHeight2) {
            foreach(x; offsetX .. newWidth2) {
                auto dest = ret[x, y];
                if(!dest)
                    return typeof(return)(dest.getError());

                auto src = source[x - offsetX, y - offsetY];
                if(!src)
                    return typeof(return)(dest.getError());

                auto got = src.convertInto(dest);
                if(!got)
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

    if(source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    if(colorSpace.isNull)
        colorSpace = source.colorSpace;

    const newWidth = cast(ptrdiff_t)(source.width * xScale), newHeight = cast(ptrdiff_t)(source.height * yScale);

    if(newWidth <= 0 || newHeight <= 0)
        return typeof(return)(MalformedInputException("New size calculation cannot be below or equal to zero"));

    Image ret = Image(colorSpace, cast(size_t)newWidth, cast(size_t)newHeight, allocator);

    void fillInAuxiliary(scope ref Pixel output, scope ref PixelReference firstPixel, scope ref PixelReference secondPixel,
            double ratio1, double ratio2) {
        foreach(c; colorSpace.channels) {
            if(!c.isAuxiliary || c.blendMode == ChannelSpecification.BlendMode.ExactOrDefaultOnly)
                continue;

            bool gotOne;
            double temp = 0;

            {
                auto got2 = firstPixel.channel01(c.name);
                if(got2) {
                    temp += got2.get * ratio1;
                    gotOne = true;
                }
            }

            {
                auto got2 = secondPixel.channel01(c.name);
                if(got2) {
                    temp += got2.get * ratio2;
                    gotOne = true;
                }
            }

            if(gotOne) {
                cast(void)output.channel01(c.name, temp);
            }
        }
    }

    foreach(y; 0 .. newHeight) {
        foreach(x; 0 .. newWidth) {
            auto dest = ret[x, y];
            if(!dest)
                return typeof(return)(dest.getError());

            const src1X = x / xScale, src2X = (x + 1) / xScale, src1Y = y / yScale, src2Y = (y + 1) / yScale;
            const secondRatio = ((src1X - floor(src1X)) + (src1Y - floor(src1Y))) / 2, firstRatio = 1 - secondRatio;

            auto firstPixel = source[cast(size_t)src1X, cast(size_t)src1Y], secondPixel = source[cast(size_t)src2X, cast(size_t)src2Y];
            if(!firstPixel)
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

            fillInAuxiliary(dest, firstPixel, secondPixel, firstRatio, secondRatio);
        }
    }

    return typeof(return)(ret);
}

/// Positive angle is clockwise, no interpolation point-by-point transformation via shear, uses center as pivot point
Result!Image rotate(scope Image source, double radianAngle, scope Pixel fallbackColor = Pixel.init,
        return scope ColorSpace colorSpace = ColorSpace.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.math.linear_algebra;
    import sidero.base.math.utils : floor;
    import std.math : isNaN, isInfinity;
    import core.stdc.math : sin, cos, tan;

    if(source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if(isNaN(radianAngle) || isInfinity(radianAngle))
        return typeof(return)(
                MalformedInputException("Angle of ration should be limited between -2PI and 2PI (radians), not infinity or NaN"));

    if(colorSpace.isNull)
        colorSpace = source.colorSpace;

    // Our goal here is to do a point-by-point rotation, without interpolation
    //  this is actually pretty easy to do, but we're gonna switch it up a bit
    //  we'll do it from the output pixel rather than the input.
    // This may not make a whole lot of sense at first, but the goal is to prevent aliasing.

    alias M = Mat2x2d, Vd = Vec2d, Vi = Vector!(size_t, 2);

    const cosAngle = cos(radianAngle), sinAngle = sin(radianAngle), tanAngle = tan(radianAngle / 2);
    const originalSize = Vd(source.width, source.height), newSize = () {
        const m1 = M(cosAngle, -sinAngle, sinAngle, cosAngle), m2 = M(-cosAngle, -sinAngle, -sinAngle, cosAngle);
        const v1 = m1.dotProduct(originalSize), v2 = m2.dotProduct(originalSize);
        const ret = cast(Vd)cast(Vi)(vector.max(v1.abs, v2.abs));
        return ret;
    }(), offset = (newSize - originalSize) / 2, newOrigin = newSize / 2, oldOrigin = originalSize / 2;

    Image result = Image(colorSpace, cast(size_t)newSize[0], cast(size_t)newSize[1], allocator);

    Vd shear(Vd input) {
        Vd ret = Vd(floor(input[0] - input[1] * tanAngle), input[1]);
        ret[1] = floor(ret[0] * sinAngle + ret[1]);
        ret[0] = floor(ret[0] - ret[1] * tanAngle);
        return ret;
    }

    if(!fallbackColor.isNull) {
        foreach(y; 0 .. newSize[1]) {
            foreach(x; 0 .. newSize[0]) {
                auto output = result[cast(size_t)x, cast(size_t)y];
                if(!output)
                    return typeof(return)(output.getError());

                cast(void)fallbackColor.convertInto(output);
            }
        }
    }

    foreach(y; offset[1] .. originalSize[1] + offset[1]) {
        if(!fallbackColor.isNull) {
            foreach(x; 0 .. offset[0]) {
                auto output = result[cast(size_t)x, cast(size_t)y];
                if(!output)
                    return typeof(return)(output.getError());

                cast(void)fallbackColor.convertInto(output);
            }
        }

        foreach(x; offset[0] .. originalSize[0] + offset[0]) {
            auto output = result[cast(size_t)x, cast(size_t)y];
            if(!output)
                return typeof(return)(output.getError());

            const cPoint = Vd(x, y), oldLoc = (newSize - 1) - cPoint - newOrigin, newLoc = oldOrigin - shear(oldLoc);

            if(newLoc[0] < 0 || newLoc[1] < 0 || newLoc[0] >= originalSize[0] || newLoc[1] >= originalSize[1]) {
                if(!fallbackColor.isNull)
                    cast(void)fallbackColor.convertInto(output);
            } else {
                const newLoc2 = cast(Vector!(size_t, 2))newLoc;

                auto got = source[newLoc2[0], newLoc2[1]];
                if(!got)
                    return typeof(return)(got.getError());

                cast(void)got.convertInto(output);
            }
        }

        if(!fallbackColor.isNull) {
            foreach(x; originalSize[0] + offset[0] .. newSize[0]) {
                auto output = result[cast(size_t)x, cast(size_t)y];
                if(!output)
                    return typeof(return)(output.getError());

                cast(void)fallbackColor.convertInto(output);
            }
        }
    }

    if(!fallbackColor.isNull) {
        foreach(y; originalSize[1] + offset[1] .. newSize[1]) {
            foreach(x; 0 .. newSize[0]) {
                auto output = result[cast(size_t)x, cast(size_t)y];
                if(!output)
                    return typeof(return)(output.getError());

                cast(void)fallbackColor.convertInto(output);
            }
        }
    }

    return result;
}
