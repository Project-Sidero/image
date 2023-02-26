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

        Vec3d got = void;

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
                got[index] = channel.sample01AsRange(value);
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(labToXYZ(got), Illuminants.E_2Degrees));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != Illuminants.E_2Degrees) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, Illuminants.E_2Degrees, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const result = xyzToLab(got);

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
                channel.store01Sample(output, channel.sampleRangeAs01(result[index]));
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

    auto gotLab = gotXYZ.convertTo(colorSpace);
    assert(gotLab);

    {
        auto channel = gotLab.channel!float("L");
        assert(channel);
        assert(channel == 35);

        channel = gotLab.channel!float("a");
        assert(channel);
        assert(channel == 75);

        channel = gotLab.channel!float("b");
        assert(channel);
        assert(channel == -45);
    }
}

///
ColorSpace cie_lchAB(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("cie_lch_ab").asReadOnly;
    state.whitePoint = Illuminants.E_2Degrees;

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
        channels[2].minimum = 0;
        channels[2].maximum = 360;
        channels[2].wrapAroundMinimum = true;
        channels[2].wrapAroundMaximum = true;

        channels[0].name = ChannelL;
        channels[1].name = ChannelC;
        channels[2].name = ChannelH;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;
        import std.math : PI;
        import core.stdc.math : cos, sin;

        Vec3d got = void;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            const value = channel.extractSample01(input);

            if (channel.name is ChannelL)
                index = 0;
            else if (channel.name is ChannelC)
                index = 1;
            else if (channel.name is ChannelH)
                index = 2;

            if (index >= 0) {
                got[index] = channel.sample01AsRange(value);
            }
        }

        const DegreeToRadian = PI / 180f;
        got[2] *= DegreeToRadian;

        const resultLab = Vec3d(got[0], cos(got[2]) * got[1], sin(got[2]) * got[1]);

        const result = labToXYZ(resultLab);
        return Result!CIEXYZSample(CIEXYZSample(result, state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;
        import std.math : PI;
        import core.stdc.math : sqrt, atan2;

        Vec3d got = input.sample;

        if (input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const resultLab = xyzToLab(got);
        const RadianToDegree = 180f / PI;

        const resultH1 = atan2(resultLab[2], resultLab[1]);
        const resultH = resultH1 >= 0 ? resultH1 : (resultH1 + (2 * PI));
        const result = Vec3d(resultLab[0], sqrt((resultLab[1] * resultLab[1]) + (resultLab[2] * resultLab[2])),
        resultH * RadianToDegree);

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelL)
                index = 0;
            else if (channel.name is ChannelC)
                index = 1;
            else if (channel.name is ChannelH)
                index = 2;

            if (output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if (index >= 0)
                channel.store01Sample(output, channel.sampleRangeAs01(result[index]));
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

    ColorSpace colorSpace = cie_lchAB(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("L");
        assert(channel);
        channel = 76;

        channel = pixel.channel!float("c");
        assert(channel);
        channel = 51;

        channel = pixel.channel!float("h");
        assert(channel);
        channel = 211;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.351406);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.498872);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.790012);
    }

    auto gotLCH = gotXYZ.convertTo(colorSpace);
    assert(gotLCH);

    {
        auto channel = gotLCH.channel!float("L");
        assert(channel);
        assert(channel == 76);

        channel = gotLCH.channel!float("c");
        assert(channel);
        assert(channel == 51);

        channel = gotLCH.channel!float("h");
        assert(channel);
        assert(channel == 211);
    }
}

private:
static ChannelL = "L", ChannelA = "a", ChannelB = "b", ChannelC = "c", ChannelH = "h";

Vec3d labToXYZ(Vec3d input) {
    import core.stdc.math : pow;

    const e = 2.16 / cast(double)24389;
    const k = 243.89 / cast(double)27;
    const whitePoint = Illuminants.E_2Degrees.asXYZ;

    const fy = (input[0] + 16) / 116;
    const fx = (input[1] / 500) + fy;
    const fz = fy - (input[2] / 200);

    const xrc = pow(fx, 3f);
    const xr = xrc > e ? xrc : ((116 * fx - 16) / k);
    const yr = input[0] > k * e ? pow((input[0] + 16) / 116, 3f) : (input[0] / k); // ok
    const zrc = pow(fz, 3f);
    const zr = zrc > e ? zrc : ((116 * fz - 16) / k);

    const resultA = Vec3d(xr, yr, zr);
    return resultA * whitePoint;
}

Vec3d xyzToLab(Vec3d input) {
    const e = 2.16 / cast(double)24389;
    const k = 243.89 / cast(double)27;

    const whitePoint = Illuminants.E_2Degrees.asXYZ;
    const xyzr = input / whitePoint;

    const fc = xyzr ^^ (1 / 3f); // should be CTFE'd
    const fx = fc[0] > e ? fc[0] : ((k * xyzr[0] + 16) / 116);
    const fy = fc[1] > e ? fc[1] : ((k * xyzr[1] + 16) / 116);
    const fz = fc[2] > e ? fc[2] : ((k * xyzr[2] + 16) / 116);

    const ret = Vec3d(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
    return ret;
}
