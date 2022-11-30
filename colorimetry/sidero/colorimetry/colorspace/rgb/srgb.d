module sidero.colorimetry.colorspace.rgb.srgb;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.errors;
import sidero.base.allocators;

@safe nothrow @nogc:

///
static immutable CIEChromacityCoordinate[3] sRGBChromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.3, 0.6), CIEChromacityCoordinate(0.15, 0.06)
];

///
ColorSpace sRGB(ubyte channelBitCount, bool isFloat, bool isLinear = false, bool approxGamma = false) {
    import sidero.base.text;

    if (isLinear) {
        auto gamma = GammaNone.init;
        auto name = format("sRGB_%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaNone(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, GammaNone.init, RCAllocator.init, name);
    } else if (approxGamma) {
        auto gamma = GammaPower(2.2);
        auto name = format("sRGB_%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, gamma, RCAllocator.init, name);
    } else {
        auto gamma = sRGBGamma.init;
        auto name = format("sRGB_%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!sRGBGamma(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, gamma, RCAllocator.init, name);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // linear
    ColorSpace colorSpace = sRGB(32, true, true), asColorSpace = cieXYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    auto channel1 = pixel.channel!float("r");
    assert(channel1);
    channel1 = 0.8;

    channel1 = pixel.channel!float("g");
    assert(channel1);
    channel1 = 0.85;

    channel1 = pixel.channel!float("b");
    assert(channel1);
    channel1 = 0.9;

    auto got = pixel.convertTo(asColorSpace);
    assert(got);

    auto channel2 = got.channel!float("x");
    assert(channel2);
    assert(channel2 == 0.796299);

    channel2 = got.channel!float("y");
    assert(channel2);
    assert(channel2 == 0.842975);

    channel2 = got.channel!float("z");
    assert(channel2);
    assert(channel2 == 0.972054);
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // approx power
    ColorSpace colorSpace = sRGB(32, true, false, true), asColorSpace = cieXYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    auto channel1 = pixel.channel!float("r");
    assert(channel1);
    channel1 = 0.8;

    channel1 = pixel.channel!float("g");
    assert(channel1);
    channel1 = 0.85;

    channel1 = pixel.channel!float("b");
    assert(channel1);
    channel1 = 0.9;

    auto got = pixel.convertTo(asColorSpace);
    assert(got);

    auto channel2 = got.channel!float("x");
    assert(channel2);
    assert(channel2 == 0.645644);

    channel2 = got.channel!float("y");
    assert(channel2);
    assert(channel2 == 0.687585);

    channel2 = got.channel!float("z");
    assert(channel2);
    assert(channel2 == 0.848892);
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // sRGB gamma
    ColorSpace colorSpace = sRGB(32, true, false, false), asColorSpace = cieXYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    auto channel1 = pixel.channel!float("r");
    assert(channel1);
    channel1 = 0.8;

    channel1 = pixel.channel!float("g");
    assert(channel1);
    channel1 = 0.85;

    channel1 = pixel.channel!float("b");
    assert(channel1);
    channel1 = 0.9;

    auto got = pixel.convertTo(asColorSpace);
    assert(got);

    auto channel2 = got.channel!float("x");
    assert(channel2);
    assert(channel2 == 0.638599);

    channel2 = got.channel!float("y");
    assert(channel2);
    assert(channel2 == 0.680185);

    channel2 = got.channel!float("z");
    assert(channel2);
    assert(channel2 == 0.842445);
}

///
ColorSpace sRGBPower(ubyte channelBitCount, bool isFloat, double gammaPowerFactor) {
    return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, GammaPower(gammaPowerFactor));
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    ColorSpace colorSpace = sRGBPower(8, false, 1f), asColorSpace = cieXYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    auto channel1 = pixel.channel!ubyte("r");
    assert(channel1);
    channel1 = 231;

    channel1 = pixel.channel!ubyte("g");
    assert(channel1);
    channel1 = 237;

    channel1 = pixel.channel!ubyte("b");
    assert(channel1);
    channel1 = 243;

    auto got = pixel.convertTo(asColorSpace);
    assert(got);

    auto channel2 = got.channel!float("x");
    assert(channel2);
    assert(channel2 == 0.877919);

    channel2 = got.channel!float("y");
    assert(channel2);
    assert(channel2 == 0.926106);

    channel2 = got.channel!float("z");
    assert(channel2);
    assert(channel2 == 1); // actually is 1.033877 but after clamping it is 1 which is correct
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    ColorSpace colorSpace = sRGBPower(32, true, 1f), asColorSpace = cieXYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    auto channel1 = pixel.channel!float("r");
    assert(channel1);
    channel1 = 0.8;

    channel1 = pixel.channel!float("g");
    assert(channel1);
    channel1 = 0.85;

    channel1 = pixel.channel!float("b");
    assert(channel1);
    channel1 = 0.9;

    auto got = pixel.convertTo(asColorSpace);
    assert(got);

    auto channel2 = got.channel!float("x");
    assert(channel2);
    assert(channel2 == 0.796299);

    channel2 = got.channel!float("y");
    assert(channel2);
    assert(channel2 == 0.842975);

    channel2 = got.channel!float("z");
    assert(channel2);
    assert(channel2 == 0.972054);
}

///
struct sRGBGamma {
@safe nothrow @nogc:

    ///
    double apply(double input) {
        if (input > 0.0031308)
            return 1.055 * (input ^^ (1 / 2.4)) - 0.055;
        else
            return input * 12.92;
    }

    ///
    double unapply(double input) {
        if (input > 0.04045)
            return ((input + 0.055) / 1.055) ^^ 2.4;
        else
            return input / 12.92;
    }
}
