module sidero.colorimetry.colorspace.rgb.itu.rec709;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.math.linear_algebra;
import sidero.base.text;
import sidero.base.errors;
import sidero.base.allocators;
import sidero.base.containers.readonlyslice;

///
static immutable CIEChromacityCoordinate[3] Rec709Chromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.3, 0.6), CIEChromacityCoordinate(0.15, 0.06)
];

/// Can only have head/foot room for 8/10 bits and not float.
ColorSpace itu_rec709_rgb(ubyte channelBitCount, bool isFloat, bool haveHeadFootRoom, bool isLinear = false,
        RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.colorimetry.colorspace.rgb.itu.rec601 : Rec601Gamma;

    if (haveHeadFootRoom && (isFloat || !(channelBitCount == 8 || channelBitCount == 10))) {
        haveHeadFootRoom = false;
    }

    double channelMin = double(0), channelMax = isFloat ? 1 : (cast(double)((1L << channelBitCount) - 1));

    if (haveHeadFootRoom && !isFloat) {
        if (channelBitCount == 8) {
            channelMin = 16;
            channelMax = 235;
        } else if (channelBitCount == 10) {
            channelMin = 64;
            channelMax = 940;
        }
    }

    if (isLinear) {
        GammaNone gamma;
        String_UTF8 name = format("rec709_rgb%s%s_%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaNone(channelBitCount, isFloat, Illuminants.D65_2Degrees, Rec709Chromacities, channelMin,
                channelMin, channelMin, channelMax, channelMax, channelMax, gamma, allocator, name);
    } else {
        Rec601Gamma gamma;
        String_UTF8 name = format("rec709_rgb%s%s_%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!Rec601Gamma(channelBitCount, isFloat, Illuminants.D65_2Degrees, Rec709Chromacities, channelMin,
                channelMin, channelMin, channelMax, channelMax, channelMax, gamma, allocator, name);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // non-linear with head/foot room
    ColorSpace colorSpace = itu_rec709_rgb(10, false, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!ushort("r");
        assert(channel);
        channel = 325;

        channel = pixel.channel!ushort("g");
        assert(channel);
        channel = 72;

        channel = pixel.channel!ushort("b");
        assert(channel);
        channel = 650;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.12499);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.056119);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.430773);
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!ushort("r");
        assert(channel);
        assert(channel == 324); // should be 325 but ya know, inaccuracies

        channel = gotRGB.channel!ushort("g");
        assert(channel);
        assert(channel == 72);

        channel = gotRGB.channel!ushort("b");
        assert(channel);
        assert(channel == 649); // should 650 but ya know, inaccuracies
    }
}

/// Can only have head/foot room for 8/10 bits and not float.
ColorSpace itu_rec709_YCbCr(ubyte channelBitCount, bool isFloat, bool haveHeadFootRoom, bool isLinear = false,
        CIEChromacityCoordinate whitePoint = Illuminants.D65_2Degrees, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.colorimetry.colorspace.rgb.itu.rec601 : Rec601Gamma;

    if (haveHeadFootRoom && (isFloat || !(channelBitCount == 8 || channelBitCount == 10))) {
        haveHeadFootRoom = false;
    }

    if (isLinear) {
        GammaNone gamma;
        String_UTF8 name = format("rec709_YCbCr%s%s_%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;

        return createYCbCr!GammaNone(channelBitCount, isFloat, haveHeadFootRoom, isLinear, allocator, gamma, Rec709Chromacities, name);
    } else {
        Rec601Gamma gamma;
        String_UTF8 name = format("rec709_YCbCr%s%s_%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;

        return createYCbCr!Rec601Gamma(channelBitCount, isFloat, haveHeadFootRoom, isLinear, allocator, gamma, Rec709Chromacities, name);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // linear without head/foot room
    ColorSpace colorSpace = itu_rec709_YCbCr(8, false, false, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!ubyte("y");
        assert(channel);
        channel = 51;

        channel = pixel.channel!ubyte("cb");
        assert(channel);
        channel = 1;

        channel = pixel.channel!ubyte("cr");
        assert(channel);
        channel = 114;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.406631);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.2);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.213272);
    }

    auto gotYCbCr = gotXYZ.convertTo(colorSpace);
    assert(gotYCbCr);

    {
        auto channel = gotYCbCr.channel!ubyte("y");
        assert(channel);
        assert(channel == 51);

        channel = gotYCbCr.channel!ubyte("cb");
        assert(channel);
        assert(channel == 0); // should actually be 1

        channel = gotYCbCr.channel!ubyte("cr");
        assert(channel);
        assert(channel == 113); // should actually be 114
    }
}

private:

ColorSpace createYCbCr(Gamma)(ubyte channelBitCount, bool isFloat, bool haveHeadFootRoom, bool isLinear,
        RCAllocator allocator, Gamma gamma, CIEChromacityCoordinate[3] primaryChromacity, String_UTF8 name) @trusted {

    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, YCbCrModel!Gamma.sizeof);
    state.name = name;

    state.copyModelFromTo = (from, to) @trusted {
        YCbCrModel!Gamma* modelFrom = cast(YCbCrModel!Gamma*)from.getExtraSpace().ptr;
        YCbCrModel!Gamma* modelTo = cast(YCbCrModel!Gamma*)to.getExtraSpace().ptr;

        *modelTo = *modelFrom;
    };

    static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
        state.gammaApply = (double input, scope const ColorSpace.State* state) @trusted {
            YCbCrModel!Gamma* model = cast(YCbCrModel!Gamma*)state.getExtraSpace().ptr;
            return model.gammaState.apply(input);
        };

        state.gammaUnapply = (double input, scope const ColorSpace.State* state) @trusted {
            YCbCrModel!Gamma* model = cast(YCbCrModel!Gamma*)state.getExtraSpace.ptr;
            return model.gammaState.unapply(input);
        };
    }

    YCbCrModel!Gamma* model = cast(YCbCrModel!Gamma*)state.getExtraSpace().ptr;
    model.__ctor(primaryChromacity, gamma, allocator);

    {
        ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
        channels[0].bits = channelBitCount;
        channels[0].isSigned = false;
        channels[0].isWhole = !isFloat;

        channels[0].clampMinimum = true;
        channels[0].clampMaximum = true;

        channels[1] = channels[0];
        channels[2] = channels[0];

        if (haveHeadFootRoom) {
            assert(!isFloat);

            if (channelBitCount == 8) {
                channels[0].minimum = 16;
                channels[0].maximum = 235;
                channels[1].minimum = 16;
                channels[1].maximum = 240;
                channels[2].minimum = 16;
                channels[2].maximum = 240;
            } else if (channelBitCount == 10) {
                channels[0].minimum = 64;
                channels[0].maximum = 940;
                channels[1].minimum = 64;
                channels[1].maximum = 960;
                channels[2].minimum = 64;
                channels[2].maximum = 960;
            } else
                assert(0);
        } else {
            const minimum = double(0), maximum = isFloat ? 1 : (cast(double)((1L << channelBitCount) - 1));

            channels[0].minimum = minimum;
            channels[0].maximum = maximum;
            channels[1].minimum = minimum;
            channels[1].maximum = maximum;
            channels[2].minimum = minimum;
            channels[2].maximum = maximum;
        }

        channels[0].name = model.ChannelY;
        channels[1].name = model.ChannelCb;
        channels[2].name = model.ChannelCr;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        YCbCrModel!Gamma* model = cast(YCbCrModel!Gamma*)state.getExtraSpace.ptr;
        Vec3d sample;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            double value = channel.extractSample01(input);

            if (channel.name is model.ChannelY)
                index = 0;
            else if (channel.name is model.ChannelCb)
                index = 1;
            else if (channel.name is model.ChannelCr)
                index = 2;

            if (index >= 0) {
                sample[index] = value;

                static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
                    sample[index] = model.gammaState.unapply(sample[index]);
                }
            }
        }

        const resultRGB = model.toRGB.dotProduct(sample);
        const resultXYZ = model.toXYZ.dotProduct(resultRGB);
        return Result!CIEXYZSample(CIEXYZSample(resultXYZ, Illuminants.D65_2Degrees));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        YCbCrModel!Gamma* model = cast(YCbCrModel!Gamma*)state.getExtraSpace.ptr;
        Vec3d asRGB = model.fromXYZ.dotProduct(input.sample);

        if (Illuminants.D65_2Degrees.asXYZ != input.whitePoint.asXYZ) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, Illuminants.D65_2Degrees, ScalingMethod.Bradford);
            asRGB = adapt.dotProduct(asRGB);
        }

        auto asYCbCr = model.fromRGB.dotProduct(asRGB);

        static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
            asYCbCr[0] = model.gammaState.apply(asYCbCr[0]);
            asYCbCr[1] = model.gammaState.apply(asYCbCr[1]);
            asYCbCr[2] = model.gammaState.apply(asYCbCr[2]);
        }

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is model.ChannelY)
                index = 0;
            else if (channel.name is model.ChannelCb)
                index = 1;
            else if (channel.name is model.ChannelCr)
                index = 2;

            if (output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if (index >= 0)
                channel.store01Sample(output, asYCbCr[index]);
            else
                channel.storeDefaultSample(output);
        }

        return ErrorResult.init;
    };

    return state.construct();
}

struct YCbCrModel(Gamma) {
    CIEChromacityCoordinate[3] primaryChromacity;
    Gamma gammaState;

    Mat3x3d toXYZ, toRGB, fromXYZ, fromRGB;

    static ChannelY = "y", ChannelCb = "cb", ChannelCr = "cr";

@safe nothrow @nogc:

    this(CIEChromacityCoordinate[3] primaryChromacity, Gamma gamma, RCAllocator allocator) {
        this.primaryChromacity = primaryChromacity;
        this.gammaState = gamma;

        {
            import sidero.colorimetry.colorspace.rgb.chromaticadaption;

            toXYZ = matrixForChromaticAdaptionRGBToXYZ(primaryChromacity, Illuminants.D65_2Degrees, Illuminants.D65_2Degrees, ScalingMethod.init);
            fromXYZ = toXYZ.inverse;
        }

        {
            const mat30_1 = Mat3x3d(0.2126, 0.7152, 0.0722, -0.2126, -0.7152, 0.9278, 0.7874, -0.7152, -0.0722);
            auto mat30_3 = cast()mat30_1;
            mat30_3[allRowColumns, 1] *= 1f / 1.8556;
            mat30_3[allRowColumns, 2] *= 1f / 1.5748;

            // Y'PbPr

            const mat30_4 = mat30_3.inverse;

            fromRGB = mat30_3;
            toRGB = mat30_4;
        }
    }

    this(scope ref YCbCrModel other) scope @trusted {
        static foreach (i; 0 .. YCbCrModel.tupleof.length)
            this.tupleof[i] = other.tupleof[i];
    }
}
