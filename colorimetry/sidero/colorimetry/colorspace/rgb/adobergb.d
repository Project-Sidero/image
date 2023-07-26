module sidero.colorimetry.colorspace.rgb.adobergb;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.errors;
import sidero.base.allocators;

@safe nothrow @nogc:

///
static immutable CIEChromacityCoordinate[3] AdobeRGBChromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.21, 0.71), CIEChromacityCoordinate(0.15, 0.06)
];

///
ColorSpace adobeRGB(ubyte channelBitCount, bool isFloat, bool isLinear = false) {
    import sidero.base.text;

    if(isLinear) {
        auto gamma = GammaNone.init;
        auto name = formattedWrite("AdobeRGB_{:s}{:s}{:s}", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaNone(channelBitCount, isFloat, Illuminants.D65_2Degrees, AdobeRGBChromacities, GammaNone.init,
                RCAllocator.init, name);
    } else {
        auto gamma = GammaPower(2.19921875);
        auto name = formattedWrite("AdobeRGB_{:s}{:s}{:s}", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, AdobeRGBChromacities, gamma, RCAllocator.init, name);
    }
}

///
unittest {
    import sidero.colorimetry.pixel;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.math.linear_algebra;

    // linear
    ColorSpace colorSpace = adobeRGB(32, true, true), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
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
        assert(channel == 0.788441);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.838897);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.973773);
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

    // non-linear
    ColorSpace colorSpace = adobeRGB(32, true, false), asColorSpace = cie_XYZ(32, Illuminants.D65_2Degrees);
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
        assert(channel == 0.632092);

        channel = gotXYZ.channel!float("y");
        assert(channel);
        assert(channel == 0.680574);

        channel = gotXYZ.channel!float("z");
        assert(channel);
        assert(channel == 0.852173);
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
