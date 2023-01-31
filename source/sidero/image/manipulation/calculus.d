module sidero.image.manipulation.calculus;
import sidero.image.defs;
import sidero.colorimetry;
import sidero.base.math.linear_algebra;
import sidero.base.allocators;
import sidero.base.errors;

export @safe nothrow @nogc:

// output op= sum(intensity1 * image1, intensity2 * image2, ...) * sumIntensity
// output op= average(intensity1 * image1, intensity2 * image2, ...) * sumIntensity

struct Sum {
    Op op;

    Image[] images;
    float[] intensities;

    bool average;
    float sumIntensity;

    enum Op {
        Set,
        Add
    }
}

///
Result!Image overOf(scope Image first, scope Image second, scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) {
    return overOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image overOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) @trusted {

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
Result!Image inOf(scope Image first, scope Image second, scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) {
    return inOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image inOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) @trusted {

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
Result!Image outOf(scope Image first, scope Image second, scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) {
    return outOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image outOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) @trusted {

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
Result!Image atopOf(scope Image first, scope Image second, scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) {
    return atopOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image atopOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) @trusted {

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
Result!Image xorOf(scope Image first, scope Image second, scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) {
    return xorOf(first, Image.init, second, Image.init, fallbackColor, allocator);
}

/// Ditto
Result!Image xorOf(scope Image first, scope Image firstMatte, scope Image second, scope Image secondMatte,
        scope Pixel fallbackColor, scope return RCAllocator allocator = RCAllocator.init) @trusted {

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

private:

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

    const firstHaveAlpha = first.colorSpace.haveChannel("a"), firstNeedsMatte = !firstHaveAlpha && !firstMatte.isNull &&
        firstMatte.colorSpace.haveChannel("Y"), firstNeedsCA = result.colorSpace.whitePoint != first.colorSpace.whitePoint,
        secondHaveAlpha = second.colorSpace.haveChannel("a"), secondNeedsMatte = !secondHaveAlpha &&
        !secondMatte.isNull && secondMatte.colorSpace.haveChannel("Y"),
        secondNeedsCA = result.colorSpace.whitePoint != second.colorSpace.whitePoint;

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


    // foreach pixel, get, multiply both vectors with Fa/Fb
    assert(0);
}
