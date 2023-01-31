module sidero.colorimetry.colorspace.cie.xyy;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_xyY(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("cie_xyY").asReadOnly;
    state.whitePoint = Illuminants.E_2Degrees;

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
        channels[2].name = ChannelY2;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = void;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            const value = channel.extractSample01(input);

            if (channel.name is ChannelX)
                index = 0;
            else if (channel.name is ChannelY)
                index = 1;
            else if (channel.name is ChannelY2)
                index = 2;

            if (index >= 0) {
                got[index] = value;
            }
        }

        const result = Vec3d((got[0] * got[2]) / got[1], got[2], ((1f - got[0] - got[1]) * got[2]) / got[1]);
        return Result!CIEXYZSample(CIEXYZSample(result, state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const result = Vec3d(got[0] / (got[0] + got[1] + got[2]), got[1] / (got[0] + got[1] + got[2]), got[1]);

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelX)
                index = 0;
            else if (channel.name is ChannelY)
                index = 1;
            else if (channel.name is ChannelY2)
                index = 2;

            if (output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if (index >= 0)
                channel.store01Sample(output, result[index]);
            else
                channel.storeDefaultSample(output);
        }

        return ErrorResult.init;
    };

    return state.construct();
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    ColorSpace colorSpace = cie_xyY(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("x");
        assert(channel);
        channel = 0.45;

        channel = pixel.channel!float("y");
        assert(channel);
        channel = 0.4;

        channel = pixel.channel!float("Y");
        assert(channel);
        channel = 0.15;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.168750);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.150000);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.056250);
    }

    auto gotxyY = gotXYZ.convertTo(colorSpace);
    assert(gotxyY);

    {
        auto channel = gotxyY.channel!float("x");
        assert(channel);
        assert(channel == 0.45);

        channel = gotxyY.channel!float("y");
        assert(channel);
        assert(channel == 0.4);

        channel = gotxyY.channel!float("Y");
        assert(channel);
        assert(channel == 0.15);
    }
}

private:
static ChannelX = "x", ChannelY = "y", ChannelY2 = "Y";
