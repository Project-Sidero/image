module sidero.image.manipulation.filter;
import sidero.image.defs;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.pixel;
import sidero.base.errors;
import sidero.base.math.linear_algebra;

export @safe nothrow @nogc:

/// Will perform an in-place threshold filter of black <= threshold < white, only considers luminosity.
ErrorResult thresholdFilter(return scope Image image, double threshold, double lowerDelta = 0, double upperDelta = 0) {
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
        bool allMustMatch = false) {
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

// convolution filter is Matrix where m:n is an odd number
// https://en.wikipedia.org/wiki/Kernel_(image_processing)

// edge handling:
// extend, wrap, mirror, crop, kernel crop, constant
