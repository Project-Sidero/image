module sidero.colorimetry.colorspace.grayscale;
import sidero.colorimetry.colorspace.defs;
import sidero.base.containers.readonlyslice;
import sidero.base.math.linear_algebra;
import sidero.base.allocators;
import sidero.base.errors;

export @safe nothrow @nogc:

///
ColorSpace grayScale(ubyte channelBitCount, bool isFloat, CIEChromacityCoordinate whitePoint, RCAllocator allocator = RCAllocator.init) {
    const minimum = double(0), maximum = isFloat ? 1 : (cast(double)((1L << channelBitCount) - 1));
    return grayScale(channelBitCount, isFloat, minimum, maximum, whitePoint, allocator);
}

///
ColorSpace grayScale(ubyte channelBitCount, bool isFloat, double minimum, double maximum, CIEChromacityCoordinate whitePoint, RCAllocator allocator = RCAllocator.init) {
    import sidero.base.text;
    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("grayscale[%sx%s]", whitePoint.x, whitePoint.y).asReadOnly;
    state.whitePoint = whitePoint;

    {
        ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(1);
        channels[0].bits = channelBitCount;
        channels[0].isSigned = false;
        channels[0].isWhole = !isFloat;

        channels[0].minimum = minimum;
        channels[0].maximum = maximum;
        channels[0].clampMinimum = true;
        channels[0].clampMaximum = true;


        channels[0].name = ChannelY;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        auto channels = (cast(ColorSpace.State*)state).channels;
        Vec3d sample = [1f, 0f, 1f];

        foreach (channel; channels) {
            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            double value = channel.extractSample01(input);

            if (channel.name is ChannelY) {
                sample[1] = value;
                break;
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(sample, state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelY)
                index = 0;

            if (output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if (index >= 0) {
                channel.store01Sample(output, got[index]);
                break;
            }
        }

        return ErrorResult.init;
    };

    return state.construct();
}

private:

static string ChannelY = "Y";
