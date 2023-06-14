/**
CIE 1976 u'v' for UCS chromacity diagram
*/
module sidero.colorimetry.colorspace.cie.uvy;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_uvY(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = String_UTF8("cie_u'v'Y");
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

        channels[0].name = ChannelU;
        channels[1].name = ChannelV;
        channels[2].name = ChannelY2;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            const value = channel.extractSample01(input);

            if (channel.name is ChannelU)
                index = 0;
            else if (channel.name is ChannelV)
                index = 1;
            else if (channel.name is ChannelY2)
                index = 2;

            if (index >= 0) {
                got[index] = value;
            }
        }

        double diver = 4f * cast(double)got[1];

        Vec3d result = Vec3d((9 * got[0] * got[2]) / diver, got[2], got[2] * (12 - (3 * got[0]) - (20 * got[1])) / diver);
        return Result!CIEXYZSample(CIEXYZSample(result, state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const weighted = got[0] + (15 * got[1]) + (3 * got[2]);
        Vec3d result = Vec3d((4 * got[0]) / weighted, (9 * got[1]) / weighted, got[1]);

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelU)
                index = 0;
            else if (channel.name is ChannelV)
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

    ColorSpace colorSpace = cie_uvY(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("u'");
        assert(channel);
        channel = 0.20443;

        channel = pixel.channel!float("v'");
        assert(channel);
        channel = 0.480737;

        channel = pixel.channel!float("Y");
        assert(channel);
        channel = 1;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.956797);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 1);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.921480);
    }

    auto gotuvY = gotXYZ.convertTo(colorSpace);
    assert(gotuvY);

    {
        auto channel = gotuvY.channel!float("u'");
        assert(channel);
        channel = 0.20443;

        channel = gotuvY.channel!float("v'");
        assert(channel);
        channel = 0.480737;

        channel = gotuvY.channel!float("Y");
        assert(channel);
        channel = 1;
    }
}

private:
static ChannelU = "u'", ChannelV = "v'", ChannelY2 = "Y";
