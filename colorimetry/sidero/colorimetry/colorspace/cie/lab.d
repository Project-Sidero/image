/**
Stored in degree format for a and b

Range L: 0 .. 100
Range a&b: has no real min/max value as it is a theoretical model, but assume +-100
*/
module sidero.colorimetry.colorspace.cie.lab;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_lab(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("cie_lab").asReadOnly;

    {
        ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
        channels[0].bits = channelBitCount;
        channels[0].isSigned = true;
        channels[0].isWhole = false;

        channels[0].minimum = -100;
        channels[0].maximum = 100;
        channels[0].clampMinimum = true;
        channels[0].clampMaximum = true;

        channels[1] = channels[0];
        channels[2] = channels[0];

        channels[0].minimum = 0;
        channels[0].name = ChannelL;
        channels[1].name = ChannelA;
        channels[2].name = ChannelB;

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

            if (channel.name is ChannelL)
                index = 0;
            else if (channel.name is ChannelA)
                index = 1;
            else if (channel.name is ChannelB)
                index = 2;

            if (index >= 0) {
                got[index] = value;
            }
        }

        const e = 2.16 / cast(double)24389;
        const k = 243.89 / cast(double)27;

        const L = got[0] * 100;
        const A = (got[1] - 0.5) * 200;
        const B = (got[2] - 0.5) * 200;

        const whitePoint = Illuminants.E_2Degrees.asXYZ;

        const fy = (L + 16) / 116;
        const fx = (A / 500) + fy;
        const fz = fy - (B / 200);

        const xrc = fx ^^ 3;
        const xr = xrc > e ? xrc : ((116 * fx - 16) / k);
        const yr = L > k * e ? (((L + 16) / 116) ^^ 3) : (L / k); // ok
        const zrc = fz ^^3;
        const zr = zrc > e ? zrc : ((116 * fz - 16) / k);

        const result = Vec3d(xr, yr, zr) * whitePoint;
        return Result!CIEXYZSample(CIEXYZSample(result, Illuminants.E_2Degrees));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != Illuminants.E_2Degrees) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, Illuminants.E_2Degrees, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const e = 2.16 / cast(double)24389;
        const k = 243.89 / cast(double)27;

        const whitePoint = Illuminants.E_2Degrees.asXYZ;
        const xyzr = got / whitePoint;

        const fc = xyzr ^^ (1 / 3f);
        const fx = fc[0] > e ? fc[0] : ((k * xyzr[0] + 16) / 116);
        const fy = fc[1] > e ? fc[1] : ((k * xyzr[1] + 16) / 116);
        const fz = fc[2] > e ? fc[2] : ((k * xyzr[2] + 16) / 116);

        const result = Vec3d(1.16 * fy - 0.16,
            ((500 * (fx - fy)) + 100) / 200,
            ((200 * (fy - fz)) + 100) / 200);

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelL)
                index = 0;
            else if (channel.name is ChannelA)
                index = 1;
            else if (channel.name is ChannelB)
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

    ColorSpace colorSpace = cie_lab(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("L");
        assert(channel);
        channel = 35;

        channel = pixel.channel!float("a");
        assert(channel);
        channel = 75;

        channel = pixel.channel!float("b");
        assert(channel);
        channel = -45;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    import sidero.base.console;

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.205019);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.084984);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.293622);
    }

    auto gotxyY = gotXYZ.convertTo(colorSpace);
    assert(gotxyY);

    {
        auto channel = gotxyY.channel!float("L");
        assert(channel);
        assert(channel == 35);

        channel = gotxyY.channel!float("a");
        assert(channel);
        assert(channel == 75);

        channel = gotxyY.channel!float("b");
        assert(channel);
        assert(channel == -45);
    }
}

private:
static ChannelL = "L", ChannelA = "a", ChannelB = "b";
