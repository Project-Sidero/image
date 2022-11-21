module sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace rgb(Gamma = GammaNone)(ubyte channelBitCount, bool isFloat, CIEChromacityCoordinate whitePoint,
        CIEChromacityCoordinate[3] primaryChromacity, Gamma gamma = Gamma.init, RCAllocator allocator = RCAllocator.init) @trusted {
    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, RGBModel!Gamma.sizeof);
    state.name = "rgb";

    static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
        state.gammaApply = (double input, scope const ColorSpace.State* state) @trusted {
            RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace().ptr;
            return model.gammaState.apply(input);
        };

        state.gammaUnapply = (double input, scope const ColorSpace.State* state) @trusted {
            RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace.ptr;
            return model.gammaState.unapply(input);
        };
    }

    RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace().ptr;
    *model = RGBModel!Gamma(channelBitCount, isFloat, whitePoint, primaryChromacity, gamma, allocator);

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) @trusted {
        RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace.ptr;
        if (input.length != model.sampleSize)
            return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

        Vec3d sample;

        auto channels = model.channels;
        foreach (i, channel; channels) {
            sample[i] = channel.extractSample01(input);

            static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
                sample[i] = model.gammaState.unapply(sample[i]);
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(model.toXYZ.dotProduct(sample), model.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;
        RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace.ptr;
        if (output.length != model.sampleSize)
            return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

        Mat3x3d conversionMatrix = model.fromXYZ;

        if (model.whitePoint.asXYZ != input.whitePoint.asXYZ) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, model.whitePoint, ScalingMethod.Bradford);
            conversionMatrix = conversionMatrix.dotProduct(adapt);
        }

        Vec3d got = conversionMatrix.dotProduct(input.sample);

        static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
            got[0] = model.gammaState.apply(got[0]);
            got[1] = model.gammaState.apply(got[1]);
            got[2] = model.gammaState.apply(got[2]);
        }

        auto channels = model.channels;
        foreach (i, channel; channels) {
            channel.store01Sample(output, got[i]);
        }

        return ErrorResult.init;
    };

    state.channels = model.channels;
    return state.construct();
}

private:

struct RGBModel(Gamma) {
    CIEChromacityCoordinate whitePoint;
    CIEChromacityCoordinate[3] primaryChromacity;
    Gamma gammaState;

    Mat3x3d toXYZ, fromXYZ;
    Slice!ChannelSpecification channels;
    size_t sampleSize;

    this(ubyte channelBitCount, bool isFloat, CIEChromacityCoordinate whitePoint,
            CIEChromacityCoordinate[3] primaryChromacity, Gamma gamma, RCAllocator allocator) {
        this.whitePoint = whitePoint;
        this.primaryChromacity = primaryChromacity;
        this.gammaState = gamma;

        {
            ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
            channels[0].bits = channelBitCount;
            channels[0].isSigned = false;
            channels[0].isWhole = !isFloat;

            channels[0].minimum = 0;
            channels[0].maximum = isFloat ? 1 : (cast(double)((1L << channelBitCount) - 1));
            channels[0].clampMinimum = true;
            channels[0].clampMaximum = true;

            channels[1] = channels[0];
            channels[2] = channels[0];

            channels[0].name = "r";
            channels[1].name = "g";
            channels[2].name = "b";

            this.channels = Slice!ChannelSpecification(channels, allocator);
            sampleSize = channels[0].numberOfBytes * 3;
        }

        {
            import sidero.colorimetry.colorspace.rgb.chromaticadaption;
            toXYZ = matrixForChromaticAdaptionRGBToXYZ(primaryChromacity, whitePoint, whitePoint, ScalingMethod.init);
            fromXYZ = toXYZ.inverse;
        }
    }
}
