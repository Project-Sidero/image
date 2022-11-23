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

    state.copyModelFromTo = (from, to) @trusted {
        RGBModel!Gamma* modelFrom = cast(RGBModel!Gamma*)from.getExtraSpace().ptr;
        RGBModel!Gamma* modelTo = cast(RGBModel!Gamma*)to.getExtraSpace().ptr;

        *modelTo = *modelFrom;
    };

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
    *model = RGBModel!Gamma(whitePoint, primaryChromacity, gamma, allocator);

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

        channels[0].name = model.ChannelR;
        channels[1].name = model.ChannelG;
        channels[2].name = model.ChannelB;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace.ptr;
        Vec3d sample;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            double value = channel.extractSample01(input);

            if (channel.name is model.ChannelR)
                index = 0;
            else if (channel.name is model.ChannelG)
                index = 1;
            else if (channel.name is model.ChannelB)
                index = 2;

            if (index >= 0) {
                sample[index] = value;

                static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
                    sample[index] = model.gammaState.unapply(sample[index]);
                }
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(model.toXYZ.dotProduct(sample), model.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        RGBModel!Gamma* model = cast(RGBModel!Gamma*)state.getExtraSpace.ptr;
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

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is model.ChannelR)
                index = 0;
            else if (channel.name is model.ChannelG)
                index = 1;
            else if (channel.name is model.ChannelB)
                index = 2;

            if (output.length < channel.numberOfBytes)
                return ErrorResult(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            if (index >= 0)
                channel.store01Sample(output, got[index]);
            else
                channel.storeDefaultSample(output);
        }

        return ErrorResult.init;
    };

    return state.construct();
}

private:

struct RGBModel(Gamma) {
    CIEChromacityCoordinate whitePoint;
    CIEChromacityCoordinate[3] primaryChromacity;
    Gamma gammaState;

    Mat3x3d toXYZ, fromXYZ;

    static ChannelR = "r", ChannelG = "g", ChannelB = "b";

    @safe nothrow @nogc:

    this(CIEChromacityCoordinate whitePoint, CIEChromacityCoordinate[3] primaryChromacity, Gamma gamma, RCAllocator allocator) {
        this.whitePoint = whitePoint;
        this.primaryChromacity = primaryChromacity;
        this.gammaState = gamma;

        {
            import sidero.colorimetry.colorspace.rgb.chromaticadaption;

            toXYZ = matrixForChromaticAdaptionRGBToXYZ(primaryChromacity, whitePoint, whitePoint, ScalingMethod.init);
            fromXYZ = toXYZ.inverse;
        }
    }

    this(scope ref RGBModel other) scope @trusted {
        static foreach(i; 0 .. RGBModel.tupleof.length)
            this.tupleof[i] = other.tupleof[i];
    }
}
