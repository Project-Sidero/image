module sidero.image.manipulation.calculus;
import sidero.image.defs;
import sidero.colorimetry;
import sidero.base.math.linear_algebra;
import sidero.base.allocators;
import sidero.base.errors;
import sidero.base.containers.dynamicarray;
import sidero.base.containers.readonlyslice;

export @safe nothrow @nogc:

/// output = sum(intensity1 * image1, intensity2 * image2, ...) * sumIntensity
Result!Image sumOf(scope Image[] images, scope double[] intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, images, intensities, sumIntensity, false, fallbackColor, colorSpace, allocator);
}

/// Ditto
Result!Image sumOf(scope Slice!Image images, scope Slice!double intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, cast(Image[])images.unsafeGetLiteral, intensities.unsafeGetLiteral, sumIntensity,
            false, fallbackColor, colorSpace, allocator);
}

/// Ditto
Result!Image sumOf(scope DynamicArray!Image images, scope DynamicArray!double intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, cast(Image[])images.unsafeGetLiteral, intensities.unsafeGetLiteral, sumIntensity,
            false, fallbackColor, colorSpace, allocator);
}

/// output = average(intensity1 * image1, intensity2 * image2, ...) * sumIntensity
Result!Image averageOf(scope Image[] images, scope double[] intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, images, intensities, sumIntensity, true, fallbackColor, colorSpace, allocator);
}

/// Ditto
Result!Image averageOf(scope Slice!Image images, scope Slice!double intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, cast(Image[])images.unsafeGetLiteral, intensities.unsafeGetLiteral, sumIntensity, true,
            fallbackColor, colorSpace, allocator);
}

/// Ditto
Result!Image averageOf(scope DynamicArray!Image images, scope DynamicArray!double intensities, double sumIntensity,
        scope Pixel fallbackColor = Pixel.init, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted {

    return arithmeticOperationWrapper(false, cast(Image[])images.unsafeGetLiteral, intensities.unsafeGetLiteral, sumIntensity,
            false, fallbackColor, colorSpace, allocator);
}

///
Result!Image overOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return overOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image overOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => 1, (double a, double b) => 1 - a);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

///
Result!Image inOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return inOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image inOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => b, (double a, double b) => 0);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

///
Result!Image outOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return outOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image outOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => 1 - b, (double a, double b) => 0);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

///
Result!Image atopOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return atopOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image atopOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => b, (double a, double b) => 1 - a);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

///
Result!Image xorOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return xorOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image xorOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => 1 - b, (double a, double b) => 1 - a);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

///
Result!Image plusOf(scope Image first, scope Image second, scope Pixel fallbackColor = Pixel.init,
        return scope RCAllocator allocator = RCAllocator.init) {
    return plusOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image plusOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor = Pixel.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {

    import std.algorithm : max;

    if (first.isNull)
        return typeof(return)(NullPointerException("First image must not be null"));
    else if (second.isNull)
        return typeof(return)(NullPointerException("second image must not be null"));

    size_t resultWidth = max(first.width, second.width, firstMatte.isNull ? 0 : firstMatte.width, secondMatte.isNull ?
            0 : secondMatte.width), resultHeight = max(first.height, second.height, firstMatte.isNull ?
            0 : firstMatte.height, secondMatte.isNull ? 0 : secondMatte.height);
    Image result = Image(first.colorSpace, resultWidth, resultHeight, allocator);

    auto errored = booleanOperation(result, first, firstMatte, second, secondMatte, fallbackColor, (double a,
            double b) => 1, (double a, double b) => 1);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

private:

Result!Image arithmeticOperationWrapper(bool addNotSet, scope Image[] images, scope const double[] intensities,
        double sumIntensity, bool average, scope Pixel fallbackColor = Pixel.init,
        return scope ColorSpace colorSpace = ColorSpace.init, return scope RCAllocator allocator = RCAllocator.init) @trusted {
    import std.math : isInfinity, isNaN;

    if (images.length == 0)
        return typeof(return)();

    size_t resultWidth, resultHeight;

    foreach (image; images) {
        if (image.isNull)
            return typeof(return)(NullPointerException("All images must be non-null"));

        if (resultWidth < image.width)
            resultWidth = image.width;
        if (resultHeight < image.height)
            resultHeight = image.height;
    }

    foreach (intensity; intensities) {
        if (isInfinity(intensity) || isNaN(intensity))
            return typeof(return)(MalformedInputException("No intensity may be NaN or infinite"));
    }

    if (colorSpace.isNull)
        colorSpace = images[0].colorSpace;

    Image result = Image(colorSpace, resultWidth, resultHeight, allocator);
    auto errored = arithmeticOperation(result, addNotSet, images, intensities, average, sumIntensity, fallbackColor, allocator);

    if (errored)
        return typeof(return)(errored.error);
    else
        return typeof(return)(result);
}

ErrorResult arithmeticOperation(scope Image result, bool addNotSet, scope Image[] images,
        scope const double[] intensities, bool average, double sumIntensity, scope Pixel fallbackColor, return scope RCAllocator allocator) @trusted {
    import sidero.colorimetry.colorspace.cie.chromaticadaption;

    if (result.isNull || images.length == 0)
        return typeof(return).init;

    foreach (image; images) {
        if (image.isNull)
            return typeof(return)(NullPointerException("All images must be non-null"));
        else if (image.width < result.width || image.height < result.height)
            return typeof(return)(MalformedInputException("Input images must be equal to or smaller than result image"));
    }

    if (average)
        sumIntensity *= 1f / images.length;

    auto targetWhitePoint = result.colorSpace.whitePoint;

    static struct CAv {
        bool need;
        Mat3x3d matrix;
    }

    DynamicArray!CAv needCA = DynamicArray!CAv(allocator);

    {
        needCA.reserve(images.length);

        foreach (image; images) {
            auto imageWP = image.colorSpace.whitePoint;
            bool need = targetWhitePoint != imageWP;

            if (need) {
                needCA ~= CAv(true, matrixForChromaticAdaptionXYZToXYZ(imageWP, targetWhitePoint, ScalingMethod.Bradford));
            } else
                needCA ~= CAv(false);
        }
    }

    Vec3d fallbackXYZ; // default is black when Y = 0

    if (!fallbackColor.isNull) {
        auto got = fallbackColor.asXYZ;

        if (got) {
            auto fbcWP = got.whitePoint;

            if (fbcWP != targetWhitePoint) {
                auto adapt = matrixForChromaticAdaptionXYZToXYZ(fbcWP, targetWhitePoint, ScalingMethod.Bradford);
                fallbackXYZ = adapt.dotProduct(got.sample);
            } else
                fallbackXYZ = got.sample;
        }
    }

    CIEXYZSample cieXYZSample;
    cieXYZSample.whitePoint = result.colorSpace.whitePoint;

    void fillInSamples(size_t x, size_t y) {
        cieXYZSample.sample = 0;

        bool gotOne;

        foreach (imageI, image; images) {
            auto got = image[x, y];
            if (got) {
                gotOne = true;

                CIEXYZSample temp = got.asXYZ.assumeOkay;

                {
                    auto imageCAv = needCA[imageI];

                    if (imageCAv.need)
                        temp.sample = imageCAv.matrix.dotProduct(temp.sample);
                }

                if (imageI < intensities.length)
                    temp.sample *= intensities[imageI];

                cieXYZSample.sample += temp.sample;
            }
        }

        if (gotOne)
            cieXYZSample.sample *= sumIntensity;
        else
            cieXYZSample.sample = fallbackXYZ;
    }

    if (addNotSet) {
        foreach (y; 0 .. result.height) {
            foreach (x; 0 .. result.width) {
                PixelReference output = result[x, y];
                assert(output);

                fillInSamples(x, y);

                cieXYZSample.sample += output.asXYZ.assumeOkay.sample;
                output = cieXYZSample;
            }
        }
    } else {
        foreach (y; 0 .. result.height) {
            foreach (x; 0 .. result.width) {
                PixelReference output = result[x, y];
                assert(output);

                fillInSamples(x, y);
                output = cieXYZSample;
            }
        }
    }

    return typeof(return).init;
}

// Implementation of: Compositing digital images https://dl.acm.org/doi/10.1145/964965.808606
ErrorResult booleanOperation(scope Image result, scope Image first, scope Image firstMatte, scope Image second,
        scope Image secondMatte, scope Pixel fallbackColor, scope double function(double, double) @safe nothrow @nogc Fa,
        scope double function(double, double) @safe nothrow @nogc Fb) @trusted {
    import sidero.colorimetry.colorspace.cie.chromaticadaption;

    assert(!result.isNull);
    assert(!first.isNull);
    assert(!second.isNull);
    assert(result.width >= first.width);
    assert(result.width >= firstMatte.width);
    assert(result.width >= second.width);
    assert(result.width >= secondMatte.width);
    assert(result.height >= first.height);
    assert(result.height >= firstMatte.height);
    assert(result.height >= second.height);
    assert(result.height >= secondMatte.height);

    const firstHaveAlpha = first.colorSpace.haveChannel("a"), firstNeedsMatte = !firstMatte.isNull &&
        firstMatte.colorSpace.haveChannel("Y"), firstNeedsCA = result.colorSpace.whitePoint != first.colorSpace.whitePoint,
        secondHaveAlpha = second.colorSpace.haveChannel("a"), secondNeedsMatte = !secondMatte.isNull &&
        secondMatte.colorSpace.haveChannel("Y"), secondNeedsCA = result.colorSpace.whitePoint != second.colorSpace.whitePoint;

    if (!firstHaveAlpha && !firstNeedsMatte)
        return typeof(return)(MalformedInputException(
                "Boolean operations on images require some sort of matte in either explicit with Y channel or alpha (first)"));
    else if (!secondHaveAlpha && !secondNeedsMatte)
        return typeof(return)(MalformedInputException(
                "Boolean operations on images require some sort of matte in either explicit with Y channel or alpha (second)"));

    Vec3d fallbackXYZ; // default is black when Y = 0

    if (!fallbackColor.isNull) {
        auto got = fallbackColor.asXYZ;
        if (got)
            fallbackXYZ = got.sample;
    }

    const adaptFirst = firstNeedsCA ? matrixForChromaticAdaptionXYZToXYZ(first.colorSpace.whitePoint,
            result.colorSpace.whitePoint, ScalingMethod.Bradford) : Mat3x3d.init, adaptSecond = secondNeedsCA ?
        matrixForChromaticAdaptionXYZToXYZ(second.colorSpace.whitePoint,
                result.colorSpace.whitePoint, ScalingMethod.Bradford) : Mat3x3d.init;

    Vec4d[2] get(size_t x, size_t y) {
        Vec4d[2] ret;

        {
            auto pixel = first[x, y];

            if (pixel) {
                auto gotXYZ = pixel.asXYZ;
                assert(gotXYZ);

                if (firstNeedsCA) {
                    auto caXYZ = adaptFirst.dotProduct(gotXYZ.sample);
                    ret[0][0] = caXYZ[0];
                    ret[0][1] = caXYZ[1];
                    ret[0][2] = caXYZ[2];
                } else {
                    ret[0][0] = gotXYZ.sample[0];
                    ret[0][1] = gotXYZ.sample[1];
                    ret[0][2] = gotXYZ.sample[2];
                }

                if (firstNeedsMatte) {
                    auto pixelM = firstMatte[x, y];

                    if (pixelM) {
                        auto gotY = pixelM.channel01("Y");
                        assert(gotY);
                        ret[1][3] = gotY.get;
                    } else
                        ret[1][3] = 0;
                } else {
                    auto gotA = pixel.channel01("a");
                    assert(gotA);
                    ret[0][3] = gotA.get;
                }
            } else {
                ret[0][0] = fallbackXYZ[0];
                ret[0][1] = fallbackXYZ[1];
                ret[0][2] = fallbackXYZ[2];
            }
        }

        {
            auto pixel = second[x, y];

            if (pixel) {
                auto gotXYZ = pixel.asXYZ;
                assert(gotXYZ);

                if (secondNeedsCA) {
                    auto caXYZ = adaptSecond.dotProduct(gotXYZ.sample);
                    ret[0][0] = caXYZ[0];
                    ret[0][1] = caXYZ[1];
                    ret[0][2] = caXYZ[2];
                } else {
                    ret[1][0] = gotXYZ.sample[0];
                    ret[1][1] = gotXYZ.sample[1];
                    ret[1][2] = gotXYZ.sample[2];
                }

                if (secondNeedsMatte) {
                    auto pixelM = secondMatte[x, y];

                    if (pixelM) {
                        auto gotY = pixelM.channel01("Y");
                        assert(gotY);
                        ret[1][3] = gotY.get;
                    } else
                        ret[1][3] = 0;
                } else {
                    auto gotA = pixel.channel01("a");
                    assert(gotA);
                    ret[1][3] = gotA.get;
                }
            } else {
                ret[1][0] = fallbackXYZ[0];
                ret[1][1] = fallbackXYZ[1];
                ret[1][2] = fallbackXYZ[2];
            }
        }

        return ret;
    }

    CIEXYZSample cieXYZSample;
    cieXYZSample.whitePoint = result.colorSpace.whitePoint;

    foreach (y; 0 .. result.height) {
        foreach (x; 0 .. result.width) {
            PixelReference output = result[x, y];
            assert(output);

            auto got = get(x, y);
            const fa = Fa(got[0][3], got[1][3]), fb = Fb(got[0][3], got[1][3]);

            got[0] *= fa;
            got[1] *= fb;
            cieXYZSample.sample[0] = got[0][0] + got[1][0];
            cieXYZSample.sample[1] = got[0][1] + got[1][1];
            cieXYZSample.sample[2] = got[0][2] + got[1][2];

            output = cieXYZSample;
        }
    }

    return typeof(return).init;
}
