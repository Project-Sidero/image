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
ColorSpace sRGB(ubyte channelBitCount, bool isFloat, bool isLinear, bool approxGamma = false) {
    import sidero.base.text;

    if (isLinear) {
        auto gamma = GammaNone.init;
        auto name = format("sRGB_%s%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaNone(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, GammaNone.init, RCAllocator.init, name);
    } else if (approxGamma) {
        auto gamma = GammaPower(2.2);
        auto name = format("sRGB_%s%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, gamma, RCAllocator.init, name);
    } else {
        auto gamma = sRGBGamma.init;
        auto name = format("sRGB_%s%s%s%s", channelBitCount, isFloat ? "f" : "", gamma).asReadOnly;
        return rgb!sRGBGamma(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, gamma, RCAllocator.init, name);
    }
}

///
ColorSpace sRGB(ubyte channelBitCount, bool isFloat, double gammaPowerFactor) {
    return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, GammaPower(gammaPowerFactor));
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
