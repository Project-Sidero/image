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

    if(image.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if(isNaN(threshold) || isInfinity(threshold) || threshold < 0 || threshold > 1)
        return typeof(return)(MalformedInputException("Threshold values must be between 0 and 1 inclusive"));
    else if(isNaN(lowerDelta) || isInfinity(lowerDelta) || lowerDelta < 0 || lowerDelta > 1)
        return typeof(return)(MalformedInputException("Threshold lower delta values must be between 0 and 1 inclusive"));
    else if(isNaN(upperDelta) || isInfinity(upperDelta) || upperDelta < 0 || upperDelta > 1)
        return typeof(return)(MalformedInputException("Threshold upper delta values must be between 0 and 1 inclusive"));

    const lower = threshold - lowerDelta, upper = threshold + upperDelta;

    foreach(y; 0 .. image.height) {
        foreach(x; 0 .. image.width) {
            auto pixel = image[x, y];
            if(!pixel)
                return typeof(return)(pixel.getError());

            auto xyz = pixel.asXYZ;
            if(!xyz)
                return typeof(return)(xyz.getError());

            if(xyz.sample[1] <= lower) {
                xyz.sample = 0;
            } else if(xyz.sample[1] > upper) {
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

    if(image.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if(isNaN(threshold[0]) || isInfinity(threshold[0]) || threshold[0] < 0 || threshold[0] > 1 || isNaN(threshold[1]) ||
            isInfinity(threshold[1]) || threshold[1] < 0 || threshold[1] > 1 || isNaN(threshold[2]) ||
            isInfinity(threshold[2]) || threshold[2] < 0 || threshold[2] > 1)
        return typeof(return)(MalformedInputException("Threshold values must be between 0 and 1 inclusive"));
    else if(isNaN(lowerDelta) || isInfinity(lowerDelta) || lowerDelta < 0 || lowerDelta > 1)
        return typeof(return)(MalformedInputException("Threshold lower delta values must be between 0 and 1 inclusive"));
    else if(isNaN(upperDelta) || isInfinity(upperDelta) || upperDelta < 0 || upperDelta > 1)
        return typeof(return)(MalformedInputException("Threshold upper delta values must be between 0 and 1 inclusive"));

    const lower = threshold - lowerDelta, upper = threshold + upperDelta;

    if(allMustMatch) {
        foreach(y; 0 .. image.height) {
            foreach(x; 0 .. image.width) {
                auto pixel = image[x, y];
                if(!pixel)
                    return typeof(return)(pixel.getError());

                auto xyz = pixel.asXYZ;
                if(!xyz)
                    return typeof(return)(xyz.getError());

                if(xyz.sample[0] <= lower[0] && xyz.sample[1] <= lower[1] && xyz.sample[2] <= lower[2]) {
                    xyz.sample = 0;
                } else if(xyz.sample[0] > upper[0] && xyz.sample[1] > upper[1] && xyz.sample[2] > upper[2]) {
                    xyz.sample = 1;
                } else
                    continue;

                pixel = xyz.get;
            }
        }
    } else {
        foreach(y; 0 .. image.height) {
            foreach(x; 0 .. image.width) {
                auto pixel = image[x, y];
                if(!pixel)
                    return typeof(return)(pixel.getError());

                auto xyz = pixel.asXYZ;
                if(!xyz)
                    return typeof(return)(xyz.getError());

                bool changed;

                static foreach(i; 0 .. 3) {
                    if(xyz.sample[i] <= lower[i]) {
                        xyz.sample[i] = 0;
                        changed = true;
                    } else if(xyz.sample[i] > upper[i]) {
                        xyz.sample[i] = 1;
                        changed = true;
                    }
                }

                if(changed)
                    pixel = xyz.get;
            }
        }
    }

    return typeof(return).init;
}

///
enum {
    /// Laplacian without diagonals
    HighPass_Ridge1 = Mat3x3d(0, -1, 0, -1, 4, -1, 0, -1, 0),
    /// Laplacian with diagonals
    HighPass_Ridge2 = Mat3x3d(-1, -1, -1, -1, 8, -1, -1, -1, -1),
    ///
    HighPass_Sharpen = Mat3x3d(0, -1, 0, -1, 5, -1, 0,
            -1, 0),
    ///
    HighPass_MeanRemoval = Mat3x3d(-1, -1, -1, -1, 9, -1, -1, -1, -1),
    ///
    LowPass_BoxBlur = Mat3x3d.one / 9,
    ///
    LowPass_GaussianBlur3x3 = Mat3x3d(1, 2, 1, 2, 4, 2, 1, 2, 1) / 16,
    ///
    LowPass_GaussianBlur5x5 = Matrix!(double, 5,
            5)(1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, 36, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1) / 256,
    ///
    LowPass_UnsharpMask = Matrix!(double, 5, 5)(1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, -476, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1) / -256,
}

///
enum ConvolutionFilterEdge {
    /// Take last member of edge
    Extend,
    /// End restarts at start, start restarts and reflects from end
    Wrap,
    /// When outside of bounds, read inside instead by that amount, includes edge
    Mirror,
    /// Starts at width/2, height/2 of source
    SourceCrop,
    /// Ignores kernel parts out of range
    KernelCrop
}

private alias convolutionFilter3x3 = convolutionFilter!(3, 3);

/// A convolution filter with edge behavior based upon image source https://en.wikipedia.org/wiki/Kernel_(image_processing)
Result!Image convolutionFilter(size_t Width, size_t Height)(return scope Image source, Matrix!(double, Width,
        Height) filter, ConvolutionFilterEdge edge, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted
        if (Width > 0 && Height > 0 && Width % 2 == 1 && Height % 2 == 1) {
    import std.math : isInfinity, isNaN;

    if(source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else {
        foreach(v; filter.data) {
            if(isInfinity(v) || isNaN(v))
                return typeof(return)(MalformedInputException("Filter values must not be infinite or NaN"));
        }
    }

    if(colorSpace.isNull)
        colorSpace = source.colorSpace;

    const isKernelCrop = edge == ConvolutionFilterEdge.KernelCrop;
    const deltaFx = -cast(ptrdiff_t)(filter.width / 2), deltaFy = -cast(ptrdiff_t)(filter.height / 2);

    size_t startX, startY, actualWidth = source.width, actualHeight = source.height, endX, endY;
    alias AcquirePixel = PixelReference delegate(ptrdiff_t x, ptrdiff_t y) @safe nothrow @nogc;
    scope AcquirePixel acquirePixel;
    Image result;

    PixelReference handleExtend(ptrdiff_t x, ptrdiff_t y) @trusted {
        if(y < 0) {
            if(x < 0) {
                // top left
                return source[0, 0];
            } else if(x >= endX) {
                // top right
                return source[endX - 1, 0];
            } else {
                // top
                return source[x, 0];
            }
        } else if(y >= endY) {
            if(x < 0) {
                // bottom left
                return source[0, endY - 1];
            } else if(x >= endX) {
                // bottom right
                return source[endX - 1, endY - 1];
            } else {
                // bottom
                return source[x, endY - 1];
            }
        } else {
            // ok within bounds
            return source[x, y];
        }
    }

    PixelReference handleWrap(ptrdiff_t x, ptrdiff_t y) @trusted {
        if(x < 0)
            x += endX;
        else if(x >= endX)
            x = x - endX;

        if(y < 0)
            y += endY;
        else if(y >= endY)
            y = y - endY;

        return source[x, y];
    }

    PixelReference handleMirror(ptrdiff_t x, ptrdiff_t y) @trusted {
        if(x < 0)
            x = (-x) - 1;
        else if(x >= endX)
            x = endX - ((x + 1) - endX);

        if(y < 0)
            y = (-x) - 1;
        else if(y >= endY)
            y = endY - ((y + 1) - endY);

        return source[x, y];
    }

    PixelReference handleCrop(ptrdiff_t x, ptrdiff_t y) @trusted {
        if(x < 0 || y < 0 || x >= endX || y >= endY)
            return PixelReference.init;
        return source[x, y];
    }

    final switch(edge) {
    case ConvolutionFilterEdge.Extend:
        // image must be equal to or bigger than 1x1
        // nothing to do for this, since it'll be bigger than 0x0 anyway

        // on axis, use direct on border, otherwise use corner
        acquirePixel = &handleExtend;
        break;
    case ConvolutionFilterEdge.Wrap:
        // image must be bigger than filter / 2
        if(source.width <= filter.width / 2 || source.height <= filter.height / 2)
            return typeof(return)(MalformedInputException("Image source for wrap edge handling must be bigger than filter / 2"));

        acquirePixel = &handleWrap;
        break;
    case ConvolutionFilterEdge.Mirror:
        // image must be bigger than filter / 2
        if(source.width <= filter.width / 2 || source.height <= filter.height / 2)
            return typeof(return)(MalformedInputException("Image source for mirror edge handling must be bigger than filter / 2"));

        // moves coord to opposite axis
        acquirePixel = &handleMirror;
        break;
    case ConvolutionFilterEdge.SourceCrop:
        // image must be bigger than filter
        // image offset & actual width/height is adjusted based upon image - filter
        if(source.width < filter.width || source.height < filter.height)
            return typeof(
                    return)(MalformedInputException("Image source for source crop edge handling must be bigger or equal to filter"));

        startX = filter.width / 2;
        startY = filter.height / 2;
        actualWidth -= filter.width - 1;
        actualHeight -= filter.height - 1;

        // doesn't do anything extra
        acquirePixel = &handleCrop;
        break;
    case ConvolutionFilterEdge.KernelCrop:
        // image must be bigger than 1x1
        // nothing to do for this, since it'll be bigger than 0x0 anyway

        // ignores parts of kernel
        acquirePixel = &handleCrop;
        break;
    }

    endX = startX + actualWidth;
    endY = startY + actualHeight;

    result = Image(colorSpace, actualWidth, actualHeight, allocator);
    CIEXYZSample tempXYZ;

    auto startPositionPixel = source[startX, startY];
    if(!startPositionPixel)
        return typeof(return)(startPositionPixel.getError());

    {
        auto xyz = startPositionPixel.asXYZ;
        if(!xyz)
            return typeof(return)(xyz.getError());

        tempXYZ.whitePoint = xyz.whitePoint;
    }

    foreach(ptrdiff_t y; startY .. actualHeight + startY) {
        foreach(ptrdiff_t x; startX .. actualWidth + startX) {
            auto output = result[x - startX, y - startY];
            if(!output)
                return typeof(return)(output.getError());

            {
                tempXYZ.sample = 0;

                foreach(ptrdiff_t fy; deltaFy .. filter.height + deltaFy) {
                    foreach(ptrdiff_t fx; deltaFx .. filter.width + deltaFx) {
                        auto sourcePixel = acquirePixel(fx, fy);

                        if(sourcePixel.isNull) {
                            if(isKernelCrop) {
                                // does not contribute to filter
                                continue;
                            } else {
                                return typeof(return)(sourcePixel.getError());
                            }
                        }

                        const multiplier = filter[fx - deltaFx, fy - deltaFy];

                        auto xyz = sourcePixel.asXYZ;
                        if(!xyz)
                            return typeof(return)(xyz.getError());

                        tempXYZ.sample += xyz.sample * multiplier;
                    }
                }

                output = tempXYZ;
            }

            {
                foreach(channel; colorSpace.channels) {
                    if(!channel.isAuxiliary || channel.blendMode != ChannelSpecification.BlendMode.Proportional)
                        continue;
                    else if(startPositionPixel.channel01(channel.name).isNull)
                        continue;

                    double sample = 0;

                    foreach(ptrdiff_t fy; deltaFy .. filter.height + deltaFy) {
                        foreach(ptrdiff_t fx; deltaFx .. filter.width + deltaFx) {
                            auto sourcePixel = acquirePixel(fx, fy);

                            if(sourcePixel.isNull) {
                                if(isKernelCrop) {
                                    // does not contribute to filter
                                    continue;
                                } else {
                                    return typeof(return)(sourcePixel.getError());
                                }
                            }

                            const multiplier = filter[fx - deltaFx, fy - deltaFy];

                            auto got = sourcePixel.channel01(channel.name);
                            if(!got)
                                return typeof(return)(got.getError());

                            sample += got.get * multiplier;
                        }
                    }

                    cast(void)output.channel01(channel.name, sample);
                }
            }
        }
    }

    return typeof(return)(result);
}

private alias convolutionFilterConstant3x3 = convolutionFilterConstant!(3, 3);

/// A convolution filter with edge behavior using a constant to fill in missing entries
Result!Image convolutionFilterConstant(size_t Width, size_t Height)(return scope Image source, Matrix!(double, Width,
        Height) filter, Pixel constant, return scope ColorSpace colorSpace = ColorSpace.init,
        return scope RCAllocator allocator = RCAllocator.init) @trusted
        if (Width > 0 && Height > 0 && Width % 2 == 1 && Height % 2 == 1) {
    import std.math : isInfinity, isNaN;

    if(source.isNull)
        return typeof(return)(NullPointerException("Input image is null"));
    else if(constant.isNull)
        return typeof(return)(NullPointerException("Input constant pixel is null"));
    else {
        foreach(v; filter.data) {
            if(isInfinity(v) || isNaN(v))
                return typeof(return)(MalformedInputException("Filter values must not be infinite or NaN"));
        }
    }

    if(colorSpace.isNull)
        colorSpace = source.colorSpace;

    if(constant.colorSpace != source.colorSpace) {
        auto got = constant.convertTo(source.colorSpace);
        if(!got)
            return typeof(return)(got.getError());
        constant = got.get;
    }

    const deltaFx = -cast(ptrdiff_t)(filter.width / 2), deltaFy = -cast(ptrdiff_t)(filter.height / 2);
    size_t startX, startY, actualWidth = source.width, actualHeight = source.height, endX = startX + actualWidth,
        endY = startY + actualHeight;
    Image result = Image(colorSpace, actualWidth, actualHeight, allocator);
    CIEXYZSample tempXYZ;

    PixelReference acquirePixel(ptrdiff_t x, ptrdiff_t y) @trusted {
        if(x < 0 || y < 0 || x >= endX || y >= endY)
            return PixelReference(constant);
        return source[x, y];
    }

    auto startPositionPixel = source[startX, startY];
    if(!startPositionPixel)
        return typeof(return)(startPositionPixel.getError());

    {
        auto xyz = startPositionPixel.asXYZ;
        if(!xyz)
            return typeof(return)(xyz.getError());

        tempXYZ.whitePoint = xyz.whitePoint;
    }

    foreach(ptrdiff_t y; startY .. actualHeight + startY) {
        foreach(ptrdiff_t x; startX .. actualWidth + startX) {
            auto output = result[x - startX, y - startY];
            if(!output)
                return typeof(return)(output.getError());

            {
                tempXYZ.sample = 0;

                foreach(ptrdiff_t fy; deltaFy .. filter.height + deltaFy) {
                    foreach(ptrdiff_t fx; deltaFx .. filter.width + deltaFx) {
                        auto sourcePixel = acquirePixel(fx, fy);
                        if(sourcePixel.isNull)
                            return typeof(return)(sourcePixel.getError());

                        const multiplier = filter[fx - deltaFx, fy - deltaFy];

                        auto xyz = sourcePixel.asXYZ;
                        if(!xyz)
                            return typeof(return)(xyz.getError());

                        tempXYZ.sample += xyz.sample * multiplier;
                    }
                }

                output = tempXYZ;
            }

            {
                foreach(channel; colorSpace.channels) {
                    if(!channel.isAuxiliary || channel.blendMode != ChannelSpecification.BlendMode.Proportional)
                        continue;
                    else if(startPositionPixel.channel01(channel.name).isNull)
                        continue;

                    double sample = 0;

                    foreach(ptrdiff_t fy; deltaFy .. filter.height + deltaFy) {
                        foreach(ptrdiff_t fx; deltaFx .. filter.width + deltaFx) {
                            auto sourcePixel = acquirePixel(fx, fy);
                            if(sourcePixel.isNull)
                                return typeof(return)(sourcePixel.getError());

                            const multiplier = filter[fx - deltaFx, fy - deltaFy];

                            auto got = sourcePixel.channel01(channel.name);
                            if(!got)
                                return typeof(return)(got.getError());

                            sample += got.get * multiplier;
                        }
                    }

                    cast(void)output.channel01(channel.name, sample);
                }
            }
        }
    }

    return typeof(return)(result);
}
