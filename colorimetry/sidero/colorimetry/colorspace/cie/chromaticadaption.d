/// Based on: http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
module sidero.colorimetry.colorspace.cie.chromaticadaption;
import sidero.colorimetry.colorspace.defs : Illuminant;
import sidero.base.math.linear_algebra;

///
enum ScalingMethod : size_t {
    /// Worst method, be warned
    XYZ,
    ///
    Bradford,
    ///
    VonKries,
}

///
Mat3x3d matrixForChromaticAdaptionXYZToXYZ(const Illuminant illuminantSource, const Illuminant illuminantDestination, ScalingMethod method) @safe nothrow @nogc {
    const methodInfo = AllScalingMethods[method];

    Mat3x3d ma = methodInfo.ma, ima = methodInfo.ima;
    Vec3d scalingPYBsource = ma.dotProduct(Vec3d(illuminantSource.tupleof)), scalingPYBdestination = ma.dotProduct(
            Vec3d(illuminantDestination.tupleof)), scalingPYB = scalingPYBdestination / scalingPYBsource;

    Mat3x3f scaledAdapt = Mat3x3f(scalingPYB[0], 0, 0, 0, scalingPYB[1], 0, 0, 0, scalingPYB[2]);

    return ima.dotProduct(scaledAdapt).dotProduct(ma);
}

private:

struct ScalingMethodInfo {
    Mat3x3d ma, ima;

    this(double[] data...) {
        assert(data.length == 9);
        ma = Mat3x3d(data[0 .. 9]);
        ima = ma.inverse;
    }
}

static const AllScalingMethods = [
    ScalingMethodInfo(1, 0, 0, 0, 1, 0, 0, 0, 1),
    ScalingMethodInfo(0.8951, 0.2664, -0.1614, -0.7502, 1.7135, 0.0367, 0.0389, -0.0685, 1.0296),
    ScalingMethodInfo(0.40024, 0.7076, -0.08081, -0.2263, 1.16532, 0.0457, 0, 0, 0.91822)
];
static assert([__traits(allMembers, ScalingMethod)].length == AllScalingMethods.length);

unittest {
    import sidero.colorimetry.illuminants;
    auto test = matrixForChromaticAdaptionXYZToXYZ(Illuminants.D65_2Degrees, Illuminants.D50_2Degrees, ScalingMethod.Bradford);
    assert(test.equals(Mat3x3d(1.16785, 0.0298926, -0.029365, 0.0427076, 1.08347, -0.011339, -0.00352778, 0.0044722, 0.999632), 1e-2, 1e-5));
}
