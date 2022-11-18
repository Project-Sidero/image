module sidero.colorimetry.colorspace.rgb.model;
import sidero.colorimetry.colorspace.defs;
import sidero.base.containers.readonlyslice;
import sidero.base.allocators;
import sidero.base.math.linear_algebra;

struct RGBModel(Gamma) {
    Illuminant whitePoint;
    float[2][3] primaries;
    Gamma gammaState;

    Mat3x3d toXYZ, fromXYZ;
    Slice!ChannelSpecification channels;

    this(ubyte channelBitCount, bool isFloat, Illuminant whitePoint, float[2][3] primaries, Gamma gamma, RCAllocator allocator) {
        this.whitePoint = whitePoint;
        this.primaries = primaries;
        this.gammaState = gamma;

        {
            ChannelSpecification[] channels = allocator.makeArray!ChannelSpecification(3);
            channels[0].name = "r";
            channels[1].name = "g";
            channels[2].name = "b";

            channels[0].bits = channelBitCount;
            channels[1].bits = channelBitCount;
            channels[2].bits = channelBitCount;

            channels[0].isSigned = false;
            channels[1].isSigned = false;
            channels[2].isSigned = false;

            channels[0].isWhole = !isFloat;
            channels[1].isWhole = !isFloat;
            channels[2].isWhole = !isFloat;

            double min, max;

            if (isFloat) {
                min = 0;
                max = 1;
            } else {
                min = 0;
                max = cast(double)((1L << channelBitCount) - 1);
            }

            channels[0].min = min;
            channels[1].min = min;
            channels[2].min = min;

            channels[0].max = max;
            channels[1].max = max;
            channels[2].max = max;

            channels[0].clampMinimum = true;
            channels[1].clampMinimum = true;
            channels[2].clampMinimum = true;
            channels[0].clampMaximum = true;
            channels[1].clampMaximum = true;
            channels[2].clampMaximum = true;

            channels = Slice!ChannelSpecification(channels, allocator);
        }

        {
            // TODO: toXYZ, fromXYZ
        }
    }
}

/// Primaries are [r[x, y], g[x, y], b[x, y]]
ColorSpace rgb(Gamma = GammaNone)(ubyte channelBitCount, bool isFloat, Illuminant whitePoint, float[2][3] primaries, Gamma gamma = Gamma.init, RCAllocator allocator = RCAllocator.init) {
    if (allocator.isNull)
        allocator = globalAllocator();

    ColorSpace.State* state = ColorSpace.allocate(allocator, RGBModel!Gamma.sizeof);
    state.name = "rgb";

    static if (__traits(hasMember, Gamma, "apply") && __traits(hasMember, Gamma, "unapply")) {
        state.gammaApply = (double input, scope ColorSpace.State* state) {
            RGBModel* model = cast(RGBModel*)state.get().ptr;
            return model.gamma.apply(input);
        };

        state.gammaUnapply = (double input, scope ColorSpace.State* state) {
            RGBModel* model = cast(RGBModel*)state.get.ptr;
            return model.gamma.unapply(input);
        };
    }

    RGBModel* model = cast(RGBModel*)state.get().ptr;
    *model = RGBModel!Gamma(channelBitCount, isFloat, whitePoint, primaries, gamma, allocator);

    state.channels = model.channels;
    return state.construct();
}
