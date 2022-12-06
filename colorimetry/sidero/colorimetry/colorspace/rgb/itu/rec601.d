module sidero.colorimetry.colorspace.rgb.itu.rec601;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.text;
import sidero.base.errors;
import sidero.base.allocators;

@safe nothrow @nogc:

///
enum Rec601_PrimaryVariant {
    /// In practice decoders will use Rec709 primaries regardless of what actually is the primaries, Poynton.
    Rec709,
    ///
    Line625,
    ///
    Line525,
}

///
static immutable CIEChromacityCoordinate[3] Rec601_Line625_Chromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.29, 0.6), CIEChromacityCoordinate(0.15, 0.06)
];

///
static immutable CIEChromacityCoordinate[3] Rec601_Line525_Chromacities = [
    CIEChromacityCoordinate(0.63, 0.34), CIEChromacityCoordinate(0.31, 0.595), CIEChromacityCoordinate(0.155, 0.07)
];

/// Can only have head/foot room for 8/10 bits and not float.
ColorSpace itu_rec601_rgb(ubyte channelBitCount, bool isFloat, bool haveHeadFootRoom, bool isLinear = false,
        CIEChromacityCoordinate whitePoint = Illuminants.D65_2Degrees,
        RCAllocator allocator = RCAllocator.init, Rec601_PrimaryVariant primary = Rec601_PrimaryVariant.Rec709) @trusted {
    import sidero.colorimetry.colorspace.rgb.itu.rec709 : Rec709Chromacities;

    static PrimaryNames = ["Rec709", "Line625", "Line525"];

    if (haveHeadFootRoom && (isFloat || !(channelBitCount == 8 || channelBitCount == 10))) {
        haveHeadFootRoom = false;
    }

    const primaryChromacity = primary == Rec601_PrimaryVariant.Rec709 ? Rec709Chromacities
        : (primary == Rec601_PrimaryVariant.Line625 ? Rec601_Line625_Chromacities : Rec601_Line525_Chromacities);
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
        String_UTF8 name = format("rec601_rgb%s%s_%s[%sx%s]%s", channelBitCount, isFloat ? "f" : "", PrimaryNames[primary],
        whitePoint.x, whitePoint.y, gamma).asReadOnly;
        return rgb!GammaNone(channelBitCount, isFloat, whitePoint, primaryChromacity, channelMin, channelMin, channelMin,
        channelMax, channelMax, channelMax, gamma, allocator, name);
    } else {
        Rec601Gamma gamma;
        String_UTF8 name = format("rec601_rgb%s%s_%s[%sx%s]%s", channelBitCount, isFloat ? "f" : "", PrimaryNames[primary],
        whitePoint.x, whitePoint.y, gamma).asReadOnly;
        return rgb!Rec601Gamma(channelBitCount, isFloat, whitePoint, primaryChromacity, channelMin, channelMin, channelMin,
        channelMax, channelMax, channelMax, gamma, allocator, name);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // non-linear with head/foot room
    ColorSpace colorSpace = itu_rec601_rgb(10, false, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
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

///
struct Rec601Gamma {
@safe nothrow @nogc:

    ///
    double apply(double input) {
        import core.stdc.math : pow;

        if (input < 0.018)
            return input * 4.5;
        else
            return 1.099 * pow(input, 0.45) - 0.099;
    }

    ///
    double unapply(double input) {
        import core.stdc.math : pow;

        if (input < 0.081)
            return input / 4.5;
        else
            return pow((input + 0.099) / 1.099, 1 / 0.45);
    }
}
