module sidero.colorimetry.colorspace.rgb.srgb;
import sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.colorimetry.illuminants;
import sidero.base.errors;

@safe nothrow @nogc:

///
static immutable CIEChromacityCoordinate[3] sRGBChromacities = [
    CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.3, 0.6), CIEChromacityCoordinate(0.15, 0.06)
];

///
ColorSpace sRGB(ubyte channelBitCount, bool isFloat, bool isLinear, bool approxGamma = false) {
    if (isLinear)
        return rgb!GammaNone(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities);
    else if (approxGamma)
        return rgb!GammaPower(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities, GammaPower(2.2));
    else
        return rgb!sRGBGamma(channelBitCount, isFloat, Illuminants.D65_2Degrees, sRGBChromacities);
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
