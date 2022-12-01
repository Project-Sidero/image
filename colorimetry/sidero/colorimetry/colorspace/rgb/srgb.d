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
    ColorSpace colorSpace = sRGB(32, true, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("r");
        assert(channel);
        channel = 0.8;

        channel = pixel.channel!float("g");
        assert(channel);
        channel = 0.85;

        channel = pixel.channel!float("b");
        assert(channel);
        channel = 0.9;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.796299);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.842975);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.972054);
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!float("r");
        assert(channel);
        assert(channel == 0.8);

        channel = gotRGB.channel!float("g");
        assert(channel);
        assert(channel == 0.85);

        channel = gotRGB.channel!float("b");
        assert(channel);
        assert(channel == 0.9);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // approx power
    ColorSpace colorSpace = sRGB(32, true, false, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("r");
        assert(channel);
        channel = 0.8;

        channel = pixel.channel!float("g");
        assert(channel);
        channel = 0.85;

        channel = pixel.channel!float("b");
        assert(channel);
        channel = 0.9;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.645644);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.687585);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.848892);
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!float("r");
        assert(channel);
        assert(channel == 0.8);

        channel = gotRGB.channel!float("g");
        assert(channel);
        assert(channel == 0.85);

        channel = gotRGB.channel!float("b");
        assert(channel);
        assert(channel == 0.9);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // sRGB gamma
    ColorSpace colorSpace = sRGB(32, true, false, false), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("r");
        assert(channel);
        channel = 0.8;

        channel = pixel.channel!float("g");
        assert(channel);
        channel = 0.85;

        channel = pixel.channel!float("b");
        assert(channel);
        channel = 0.9;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.638599);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.680185);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.842445);
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!float("r");
        assert(channel);
        assert(channel == 0.8);

        channel = gotRGB.channel!float("g");
        assert(channel);
        assert(channel == 0.85);

        channel = gotRGB.channel!float("b");
        assert(channel);
        assert(channel == 0.9);
    }
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

    ColorSpace colorSpace = sRGBPower(8, false, 1f), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!ubyte("r");
        assert(channel);
        channel = 231;

        channel = pixel.channel!ubyte("g");
        assert(channel);
        channel = 237;

        channel = pixel.channel!ubyte("b");
        assert(channel);
        channel = 243;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.877919);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.926106);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 1); // actually is 1.033877 but after clamping it is 1 which is correct
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!ubyte("r");
        assert(channel);
        assert(channel == 235);

        channel = gotRGB.channel!ubyte("g");
        assert(channel);
        assert(channel == 236);

        channel = gotRGB.channel!ubyte("b");
        assert(channel);
        assert(channel == 233);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    ColorSpace colorSpace = sRGBPower(32, true, 1f), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
    Pixel pixel = Pixel(colorSpace);

    {
        auto channel = pixel.channel!float("r");
        assert(channel);
        channel = 0.8;

        channel = pixel.channel!float("g");
        assert(channel);
        channel = 0.85;

        channel = pixel.channel!float("b");
        assert(channel);
        channel = 0.9;
    }

    auto gotXYZ = pixel.convertTo(asColorSpace);
    assert(gotXYZ);

    {
        auto channel = gotXYZ.channel!float("x");
        assert(channel);
        assert(channel == 0.796299);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.842975);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.972054);
    }

    auto gotRGB = gotXYZ.convertTo(colorSpace);
    assert(gotRGB);

    {
        auto channel = gotRGB.channel!float("r");
        assert(channel);
        assert(channel == 0.8);

        channel = gotRGB.channel!float("g");
        assert(channel);
        assert(channel == 0.85);

        channel = gotRGB.channel!float("b");
        assert(channel);
        assert(channel == 0.9);
    }
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
