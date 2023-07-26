module sidero.colorimetry.colorspace.cie.xyz;
import sidero.colorimetry.colorspace.defs;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_XYZ(ubyte channelBitCount, CIEChromacityCoordinate whitePoint, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if(allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = formattedWrite("cieXYZ[{:s}x{:s}]", whitePoint.x, whitePoint.y).asReadOnly;
    state.whitePoint = whitePoint;

    {
        ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
        channels[0].bits = channelBitCount;
        channels[0].isSigned = false;
        channels[0].isWhole = false;

        channels[0].minimum = 0;
        channels[0].maximum = 1;
        channels[0].clampMinimum = true;
        channels[0].clampMaximum = true;

        channels[1] = channels[0];
        channels[2] = channels[0];

        channels[0].name = ChannelX;
        channels[1].name = ChannelY;
        channels[2].name = ChannelZ;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        Vec3d sample;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach(channel; channels) {
            ptrdiff_t index = -1;

            if(input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            double value = channel.extractSample01(input);

            if(channel.name is ChannelX)
                index = 0;
            else if(channel.name is ChannelY)
                index = 1;
            else if(channel.name is ChannelZ)
                index = 2;

            if(index >= 0) {
                sample[index] = value;
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(sample, state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if(input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach(channel; channels) {
            ptrdiff_t index = -1;

            if(channel.name is ChannelX)
                index = 0;
            else if(channel.name is ChannelY)
                index = 1;
            else if(channel.name is ChannelZ)
                index = 2;

            if(output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if(index >= 0)
                channel.store01Sample(output, got[index]);
            else
                channel.storeDefaultSample(output);
        }

        return ErrorResult.init;
    };

    return state.construct();
}

private:
static ChannelX = "x", ChannelY = "y", ChannelZ = "z";
