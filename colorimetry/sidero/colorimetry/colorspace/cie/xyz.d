module sidero.colorimetry.colorspace.cie.xyz;
import sidero.colorimetry.colorspace.defs;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;
import sidero.base.errors;

@safe nothrow @nogc:

///
ColorSpace cie_XYZ(ubyte channelBitCount, CIEChromacityCoordinate whitePoint, RCAllocator allocator = RCAllocator.init) @trusted {
    import sidero.base.text;
    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, XYZModel.sizeof);
    state.name = format("cieXYZ[%sx%s]", whitePoint.x, whitePoint.y).asReadOnly;

    state.copyModelFromTo = (from, to) @trusted {
        XYZModel* modelFrom = cast(XYZModel*)from.getExtraSpace().ptr;
        XYZModel* modelTo = cast(XYZModel*)to.getExtraSpace().ptr;

        *modelTo = *modelFrom;
    };

    XYZModel* model = cast(XYZModel*)state.getExtraSpace().ptr;
    *model = XYZModel(whitePoint);

    {
        ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
        channels[0].bits = channelBitCount;
        channels[0].isSigned = false;
        channels[0].isWhole = false;

        channels[0].minimum = 0;
        channels[0].maximum = 1;
        channels[0].clampMinimum = true;
        channels[0].clampMaximum = true;

        channels[1] = channels[0];
        channels[2] = channels[0];

        channels[0].name = model.ChannelX;
        channels[1].name = model.ChannelY;
        channels[2].name = model.ChannelZ;

        state.channels = Slice!ChannelSpecification(channels, allocator);
    }

    state.toXYZ = (scope void[] input, scope const ColorSpace.State* state) nothrow @trusted {
        XYZModel* model = cast(XYZModel*)state.getExtraSpace.ptr;

        Vec3d sample;

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (input.length < channel.numberOfBytes)
                return Result!CIEXYZSample(MalformedInputException("Color sample does not equal size of all channels in bytes."));

            double value = channel.extractSample01(input);

            if (channel.name is model.ChannelX)
                index = 0;
            else if (channel.name is model.ChannelY)
                index = 1;
            else if (channel.name is model.ChannelZ)
                index = 2;

            if (index >= 0) {
                sample[index] = value;
            }
        }

        return Result!CIEXYZSample(CIEXYZSample(sample, model.whitePoint));
    };

    state.fromXYZ = (scope void[] output, scope CIEXYZSample input, scope const ColorSpace.State* state) nothrow @trusted {
        import sidero.colorimetry.colorspace.cie.chromaticadaption;

        XYZModel* model = cast(XYZModel*)state.getExtraSpace.ptr;
        Vec3d got = input.sample;

        if (input.whitePoint != model.whitePoint) {
            const adapt = matrixForChromaticAdaptionXYZToXYZ(input.whitePoint, model.whitePoint, ScalingMethod.Bradford);
            got = adapt.dotProduct(got);
        }

        auto channels = (cast(ColorSpace.State*)state).channels;
        foreach (channel; channels) {
            ptrdiff_t index = -1;

            if (channel.name is model.ChannelX)
                index = 0;
            else if (channel.name is model.ChannelY)
                index = 1;
            else if (channel.name is model.ChannelZ)
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

struct XYZModel {
    CIEChromacityCoordinate whitePoint;
    static ChannelX = "x", ChannelY = "y", ChannelZ = "z";

@safe nothrow @nogc:

    this(CIEChromacityCoordinate whitePoint) {
        this.whitePoint = whitePoint;
    }

    this(scope ref XYZModel other) scope @trusted {
        static foreach (i; 0 .. XYZModel.tupleof.length)
            this.tupleof[i] = other.tupleof[i];
    }
}
