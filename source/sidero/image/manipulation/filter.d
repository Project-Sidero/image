module sidero.image.manipulation.filter;
import sidero.image.defs;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.pixel;
import sidero.base.errors;
import sidero.base.math.linear_algebra;
import sidero.base.allocators;

export @safe nothrow @nogc:

/// Will perform an in-place threshold filter of black <= threshold < white, only considers luminosity.
ErrorResult thresholdFilter(return scope Image image, double threshold, double lowerDelta = 0, double upperDelta = 0) @trusted {
    import std.math : isNaN, isInfinity;

    if (image.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if (isNaN(threshold) || isInfinity(threshold) || threshold < 0 || threshold > 1)
        return typeof(return)(MalformedInputException("Threshold values must be between 0 and 1 inclusive"));
    else if (isNaN(lowerDelta) || isInfinity(lowerDelta) || lowerDelta < 0 || lowerDelta > 1)
        return typeof(return)(MalformedInputException("Threshold lower delta values must be between 0 and 1 inclusive"));
    else if (isNaN(upperDelta) || isInfinity(upperDelta) || upperDelta < 0 || upperDelta > 1)
        return typeof(return)(MalformedInputException("Threshold upper delta values must be between 0 and 1 inclusive"));

    const lower = threshold - lowerDelta, upper = threshold + upperDelta;

    foreach (y; 0 .. image.height) {
        foreach (x; 0 .. image.width) {
            auto pixel = image[x, y];
            if (!pixel)
                return typeof(return)(pixel.getError());

            auto xyz = pixel.asXYZ;
            if (!xyz)
                return typeof(return)(xyz.getError());

            if (xyz.sample[1] <= lower) {
                xyz.sample = 0;
            } else if (xyz.sample[1] > upper) {
                xyz.sample = 1;
            } else
                continue;

            pixel = xyz.get;
        }
    }

    return typeof(return).init;
}

/// Will perform an in-place threshold filter of 0 <= threshold < 1, with respect to all CIE XYZ samples must match, or per channel setting.
ErrorResult thresholdFilter(return scope Image image, Vec3d threshold, double lowerDelta = 0, double upperDelta = 0,
        bool allMustMatch = false) @trusted {
    import std.math : isNaN, isInfinity;

    if (image.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if (isNaN(threshold[0]) || isInfinity(threshold[0]) || threshold[0] < 0 || threshold[0] > 1 ||
            isNaN(threshold[1]) || isInfinity(threshold[1]) || threshold[1] < 0 || threshold[1] > 1 || isNaN(threshold[2]) ||
            isInfinity(threshold[2]) || threshold[2] < 0 || threshold[2] > 1)
        return typeof(return)(MalformedInputException("Threshold values must be between 0 and 1 inclusive"));
    else if (isNaN(lowerDelta) || isInfinity(lowerDelta) || lowerDelta < 0 || lowerDelta > 1)
        return typeof(return)(MalformedInputException("Threshold lower delta values must be between 0 and 1 inclusive"));
    else if (isNaN(upperDelta) || isInfinity(upperDelta) || upperDelta < 0 || upperDelta > 1)
        return typeof(return)(MalformedInputException("Threshold upper delta values must be between 0 and 1 inclusive"));

    const lower = threshold - lowerDelta, upper = threshold + upperDelta;

    if (allMustMatch) {
        foreach (y; 0 .. image.height) {
            foreach (x; 0 .. image.width) {
                auto pixel = image[x, y];
                if (!pixel)
                    return typeof(return)(pixel.getError());

                auto xyz = pixel.asXYZ;
                if (!xyz)
                    return typeof(return)(xyz.getError());

                if (xyz.sample[0] <= lower[0] && xyz.sample[1] <= lower[1] && xyz.sample[2] <= lower[2]) {
                    xyz.sample = 0;
                } else if (xyz.sample[0] > upper[0] && xyz.sample[1] > upper[1] && xyz.sample[2] > upper[2]) {
                    xyz.sample = 1;
                } else
                    continue;

                pixel = xyz.get;
            }
        }
    } else {
        foreach (y; 0 .. image.height) {
            foreach (x; 0 .. image.width) {
                auto pixel = image[x, y];
                if (!pixel)
                    return typeof(return)(pixel.getError());

                auto xyz = pixel.asXYZ;
                if (!xyz)
                    return typeof(return)(xyz.getError());

                bool changed;

                static foreach (i; 0 .. 3) {
                    if (xyz.sample[i] <= lower[i]) {
                        xyz.sample[i] = 0;
                        changed = true;
                    } else if (xyz.sample[i] > upper[i]) {
                        xyz.sample[i] = 1;
                        changed = true;
                    }
                }

                if (changed)
                    pixel = xyz.get;
            }
        }
    }

    return typeof(return).init;
}

enum {
    /// Some example filters
    HighPass_Ridge1 = Mat3x3d(0, -1, 0, -1, 4, -1, 0, -1, 0),
    /// Ditto
    HighPass_Ridge2 = Mat3x3d(-1, -1, -1, -1, 8, -1, -1, -1, -1),
    /// Ditto
    HighPass_Sharpen = Mat3x3d(0, -1, 0, -1, 5, -1, 0,
            -1, 0),
    /// Ditto
    HighPass_MeanRemoval = Mat3x3d(-1, -1, -1, -1, 9, -1, -1, -1, -1),
    /// Ditto
    LowPass_BoxBlur = Mat3x3d.one,
    /// Ditto
    LowPass_GaussianBlur3x3 = Mat3x3d(1, 2, 1, 2, 4, 2, 1, 2, 1),
    /// Ditto
    LowPass_GaussianBlur5x5 = Matrix!(double, 5, 5)(1, 4,
            6, 4, 1, 4, 16, 24, 16, 4, 6, 24, 36, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1),
    /// Ditto
    LowPass_UnsharpMask = Matrix!(double, 5, 5)(1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, -476, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1),
}

///
enum ConvolutionFilterEdge {
    ///
    Extend,
    ///
    Wrap,
    ///
    Mirror,
    ///
    SourceCrop,
    ///
    KernelCrop
}

// convolution filter is Matrix where m:n is an odd number
// https://en.wikipedia.org/wiki/Kernel_(image_processing)

// edge handling:
// extend, wrap, mirror, crop, kernel crop, constant

alias convolutionFilter3x3 = convolutionFilter!(3, 3);

/// A convolution filter with edge behavior based upon image source
Result!Image convolutionFilter(size_t Width, size_t Height)(return scope Image source, Matrix!(double, Width,
        Height) filter, ConvolutionFilterEdge edge, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted
        if (Width > 0 && Height > 0 && Width % 2 == 1 && Height % 2 == 1) {
    import std.math : isInfinity, isNaN;

    if (source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else {
        foreach (v; filter.data) {
            if (isInfinity(v) || isNaN(v))
                return typeof(return)(MalformedInputException("Filter values must not be infinite or NaN"));
        }
    }

    if (colorSpace.isNull)
        colorSpace = source.colorSpace;

    size_t startX, startY, actualWidth = source.width, actualHeight = source.height;
    alias Handler = void delegate(ptrdiff_t x, ptrdiff_t y) @safe nothrow @nogc;
    scope Handler handler;
    Image result;

    void handleExtend(ptrdiff_t x, ptrdiff_t y) {

    }

    void handleWrap(ptrdiff_t x, ptrdiff_t y) {

    }

    void handleMirror(ptrdiff_t x, ptrdiff_t y) {

    }

    void handleSourceCrop(ptrdiff_t x, ptrdiff_t y) {

    }

    void handleKernelCrop(ptrdiff_t x, ptrdiff_t y) {

    }

    final switch (edge) {
    case ConvolutionFilterEdge.Extend:
        // image must be equal to or bigger than 2x2

        // on axis, use direct on border, otherwise use corner
        handler = &handleExtend;
        break;
    case ConvolutionFilterEdge.Wrap:
        // image must be equal to or bigger than filter / 2

        //
        handler = &handleWrap;
        break;
    case ConvolutionFilterEdge.Mirror:
        // image must be bigger than filter / 2

        // moves coord to opposite axis
        handler = &handleMirror;
        break;
    case ConvolutionFilterEdge.SourceCrop:
        // image must be bigger than (filter + 1) / 2
        // image offset & actual width/height is adjusted based upon image - filter

        // doesn't do anything extra
        handler = &handleSourceCrop;
        break;
    case ConvolutionFilterEdge.KernelCrop:
        // image must be bigger than 1x1

        // ignores parts of kernel
        handler = &handleKernelCrop;
        break;
    }

    result = Image(colorSpace, actualWidth, actualHeight, allocator);

    foreach (y; startY .. actualHeight + startY) {
        foreach (x; startX .. actualWidth + startX) {
            handler(x, y);
        }
    }

    return typeof(return)(result);
}

/// A convolution filter with edge behavior using a constant to fill in missing entries
Result!Image convolutionFilterConstant(size_t Width, size_t Height)(return scope Image source, Matrix!(double, Width,
        Height) filter, CIEXYZSample constant, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted
        if (Width > 0 && height > 0 && Width % 2 == 1 && Height % 2 == 1) {
    import std.math : isInfinity, isNaN;

    if (source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else {
        foreach (v; filter.data) {
            if (isInfinity(v) || isNaN(v))
                return typeof(return)(MalformedInputException("Filter values must not be infinite or NaN"));
        }

        // TODO: size check
    }

    if (colorSpace.isNull)
        colorSpace = source.colorSpace;

    size_t startX, startY, actualWidth = source.width, actualHeight = source.height;
    Image result = Image(colorSpace, actualWidth, actualHeight, allocator);

    foreach (y; startY .. actualHeight + startY) {
        foreach (x; startX .. actualWidth + startX) {
            // TODO
        }
    }

    return typeof(return)(result);
}
