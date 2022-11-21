module sidero.colorimetry.colorspace.rgb.chromaticadaption;
import sidero.colorimetry.colorspace.defs : CIEChromacityCoordinate;
public import sidero.colorimetry.colorspace.cie.chromaticadaption : ScalingMethod;
import sidero.base.math.linear_algebra;

///
Mat3x3d matrixForChromaticAdaptionRGBToXYZ(const CIEChromacityCoordinate[3] rgbChromacities,
        const CIEChromacityCoordinate illuminantSource, const CIEChromacityCoordinate illuminantDestination, ScalingMethod method) @safe nothrow @nogc {
    return matrixForRGBXYZ(RGBChromacity(rgbChromacities[0], rgbChromacities[1], rgbChromacities[2], illuminantSource),
            illuminantDestination, method);
}

private:
import sidero.colorimetry.colorspace.cie.chromaticadaption;

struct RGBChromacity {
    CIEChromacityCoordinate r, g, b, whitePoint;
}

Mat3x3d matrixForRGBXYZ(scope const RGBChromacity chromacitySource,
        scope const CIEChromacityCoordinate illuminantDestination, scope const ScalingMethod method) @safe nothrow @nogc {
    // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html

    const rXYZ = chromacitySource.r, gXYZ = chromacitySource.g, bXYZ = chromacitySource.b, wpXYZ = chromacitySource.whitePoint;
    const xr = rXYZ.x, yr = rXYZ.y, xg = gXYZ.x, yg = gXYZ.y, xb = bXYZ.x, yb = bXYZ.y;

    Mat3x3d m = Mat3x3d(xr / yr, 1, (1 - xr - yr) / yr, xg / yg, 1, (1 - xg - yg) / yg, xb / yb, 1, (1 - xb - yb) / yb);

    Mat3x3d mi = m.inverse;
    Vec3d s = mi.transpose.dotProduct(chromacitySource.whitePoint.asXYZ);

    Mat3x3d ret1 = Mat3x3d(s[0] * m[0, 0], s[0] * m[1, 0], s[0] * m[2, 0], s[1] * m[0, 1], s[1] * m[1, 1], s[1] * m[2,
            1], s[2] * m[0, 2], s[2] * m[1, 2], s[2] * m[2, 2],).transpose;
    Mat3x3d ret;

    if (illuminantDestination.asXYZ != chromacitySource.whitePoint.asXYZ) {
        const adapt = matrixForChromaticAdaptionXYZToXYZ(chromacitySource.whitePoint, illuminantDestination, method);
        ret = ret1.dotProduct(adapt);
    } else
        ret = ret1;

    return ret;
}

unittest {
    import sidero.colorimetry.illuminants;

    Mat3x3d sRGBD65 = matrixForChromaticAdaptionRGBToXYZ([
        CIEChromacityCoordinate(0.64, 0.33), CIEChromacityCoordinate(0.3, 0.6), CIEChromacityCoordinate(0.15, 0.06)
    ], Illuminants.D65_2Degrees, Illuminants.D65_2Degrees, ScalingMethod.Bradford);
    assert(sRGBD65.equals(Mat3x3d(0.4124564, 0.3575761, 0.1804375, 0.2126729, 0.7151522, 0.0721750, 0.0193339,
            0.1191920, 0.9503041), 1e-2, 1e-5));
}
