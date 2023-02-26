/**
Stored in radian format for u and v

Range L: 0 .. 100
Range u&v: has no real min/max value as it is a theoretical model, but assume +-100
*/
module sidero.colorimetry.colorspace.cie.luv;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_luv(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("cie_luv").asReadOnly;
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
        channels[0].name = ChannelL;
        channels[1].name = ChannelU;
        channels[2].name = ChannelV;

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
            else if (channel.name is ChannelU)
                index = 1;
            else if (channel.name is ChannelV)
                index = 2;

            if (index >= 0) {
                got[index] = channel.sample01AsRange(value);
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(luvToXYZ(got), state.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        Vec3d got = input.sample;

        if (input.whitePoint != state.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, state.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const result = xyzToLuv(got);

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is ChannelL)
                index = 0;
            else if (channel.name is ChannelU)
                index = 1;
            else if (channel.name is ChannelV)
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

    ColorSpace colorSpace = cie_luv(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("L");
        assert(channel);
        channel = 35;

        channel = pixel.channel!float("u");
        assert(channel);
        channel = 75;

        channel = pixel.channel!float("v");
        assert(channel);
        channel = -45;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.191509);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.084984);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.191513);
    }

    auto gotLuv = gotXYZ.convertTo(colorSpace);
    assert(gotLuv);

    {
        auto channel = gotLuv.channel!float("L");
        assert(channel);
        assert(channel == 35);

        channel = gotLuv.channel!float("u");
        assert(channel);
        assert(channel == 75);

        channel = gotLuv.channel!float("v");
        assert(channel);
        assert(channel == -45);
    }
}

///
ColorSpace cie_lchUV(ubyte channelBitCount, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, 0);
    state.name = format("cie_lch_uv").asReadOnly;

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

        const resultLuv = Vec3d(got[0], cos(got[2]) * got[1], sin(got[2]) * got[1]);

        const result = luvToXYZ(resultLuv);
        return Result!CIEXYZSample(CIEXYZSample(result, Illuminants.E_2Degrees));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;
        import std.math : PI;
        import core.stdc.math : sqrt, atan2;

        Vec3d got = input.sample;

        if (input.whitePoint != Illuminants.E_2Degrees) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, Illuminants.E_2Degrees, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        const resultLuv = xyzToLuv(got);
        const RadianToDegree = 180f / PI;

        const resultH1 = atan2(resultLuv[2], resultLuv[1]);
        const resultH = resultH1 >= 0 ? resultH1 : (resultH1 + (2 * PI));
        const result = Vec3d(resultLuv[0], sqrt((resultLuv[1] * resultLuv[1]) + (resultLuv[2] * resultLuv[2])),
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

    ColorSpace colorSpace = cie_lchUV(32), asColorSpace = cie_XYZ(32, Illuminants.E_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("L");
        assert(channel);
        channel = 35;

        channel = pixel.channel!float("c");
        assert(channel);
        channel = 75;

        channel = pixel.channel!float("h");
        assert(channel);
        channel = 160;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.020069);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.084984);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.049376);
    }

    auto gotLCH = gotXYZ.convertTo(colorSpace);
    assert(gotLCH);

    {
        auto channel = gotLCH.channel!float("L");
        assert(channel);
        assert(channel == 35);

        channel = gotLCH.channel!float("c");
        assert(channel);
        assert(channel == 75);

        channel = gotLCH.channel!float("h");
        assert(channel);
        assert(channel == 160);
    }
}

private:
static ChannelL = "L", ChannelU = "u", ChannelV = "v", ChannelC = "c", ChannelH = "h";

Vec3d luvToXYZ(Vec3d input) {
    import core.stdc.math : pow;

    const e = 216 / cast(double)24389;
    const k = 24389 / cast(double)27;
    const whitePoint = Illuminants.E_2Degrees.asXYZ;

    const valY = input[0] > (k * e) ? pow(((input[0] + 16) / 116), 3) : (input[0] / k);

    // extract u'v'
    const uvM = Vec3d(1, 15, 3);
    const u0 = (4 * whitePoint[0]) / (uvM * whitePoint).sum;
    const v0 = (9 * whitePoint[1]) / (uvM * whitePoint).sum;

    const a0 = (52 * input[0]) / (input[1] + 13 * input[0] * u0);
    const a = ((a0) - 1) / 3;

    const b = -5 * valY;
    const c = -1 / 3f;
    const d = valY * (((39 * input[0]) / (input[2] + 13 * input[0] * v0)) - 5);

    const valX = (d - b) / (a - c);
    const valZ = valX * a + b;

    const ret = Vec3d(valX, valY, valZ);
    return ret;
}

Vec3d xyzToLuv(Vec3d input) {
    import core.stdc.math : pow;

    const e = 216 / cast(double)24389;
    const k = 24389 / cast(double)27;
    const whitePoint = Illuminants.E_2Degrees.asXYZ;

    const yr = input[1] / whitePoint[1];
    const uvM = Vec3d(1, 15, 3);

    const uv = (uvM * input).sum;
    const u = (4 * input[0]) / uv;
    const v = (9 * input[1]) / uv;

    const uvr = (uvM * whitePoint).sum;
    const ur = (4 * whitePoint[0]) / uvr;
    const vr = (9 * whitePoint[1]) / uvr;

    const valL = yr > e ? (116 * pow(yr, (1 / 3f)) - 16) : (k * yr);
    const ret = Vec3d(valL, 13 * valL * (u - ur), 13 * valL * (v - vr));
    return ret;
}
