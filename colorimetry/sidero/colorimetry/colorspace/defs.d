module sidero.colorimetry.colorspace.defs;
import sidero.base.allocators;
import sidero.base.errors;
import sidero.base.containers.readonlyslice;
import sidero.base.math.linear_algebra : Vec3d;

@safe nothrow @nogc:

/// This is a CIE XYZ color sample, it should not have any gamma applied.
struct CIEXYZSample {
    /// CIE XYZ X, Y, Z channels
    double x, y, z;
    /// The white point for this sample
    CIEChromacityCoordinate illuminant;
}

///
struct CIEChromacityCoordinate {
    ///
    CIExyYSample xyY;
    ///
    alias xyY this;

@safe nothrow @nogc:

    this(double x, double y) scope {
        xyY.x = x;
        xyY.y = y;
    }

    ///
    double z() scope const pure {
        return 1 - (xyY.x + xyY.y);
    }
}

///
struct CIExyYSample {
    ///
    double x, y, Y = 1;

@safe nothrow @nogc:

    ///
    Vec3d asXYZ() scope const pure {
        return Vec3d((x * Y) / y, Y, ((1f - x - y) * Y) / y);
    }
}

///
struct ColorSpace {
    private {
        import core.atomic : atomicLoad, atomicOp;
        State* state;
    }

@safe nothrow @nogc:

    this(ref ColorSpace other) scope {
        this.state = other.state;

        if (state !is null)
            atomicOp!"+="(state.refCount, 1);
    }

    ~this() scope @trusted {
        if (state !is null && atomicOp!"-="(state.refCount, 1) == 0) {
            RCAllocator allocator = state.allocator;
            void[] data = (cast(void*)state)[0 .. State.sizeof + state.length];
            allocator.dispose(data);
        }
    }

    ///
    bool isNull() scope {
        return state is null;
    }

    ///
    alias toString = name;

    ///
    string name() scope const {
        if (state is null)
            return null;
        return state.name;
    }

    ///
    Slice!ChannelSpecification channels() scope {
        if (state is null)
            return typeof(return).init;
        return state.channels;
    }

    /// You may not need to call this, gamma is done automatically during conversion
    double gammaApply(double input) scope const {
        if (state is null || state.gammaApply is null)
            return input;
        return state.gammaApply(input, state);
    }

    /// Ditto
    double gammaUnapply(double input) scope const {
        if (state is null || state.gammaUnapply is null)
            return input;
        return state.gammaUnapply(input, state);
    }

    /// Gamma will be automatically applied
    Result!CIEXYZSample toXYZ(scope void[] input) scope const {
        if (state is null || state.toXYZ is null)
            return typeof(return)(NullPointerException("toXYZ is not implemented"));
        return state.toXYZ(input, state);
    }

    /// Gamma will be automatically removed
    ErrorResult fromXYZ(scope void[] output, scope CIEXYZSample input) scope const {
        if (state is null || state.fromXYZ is null)
            return typeof(return)(NullPointerException("fromXYZ is not implemented"));
        return state.fromXYZ(output, input, state);
    }

    struct State {
        private {
            shared(int) refCount = 1;
            RCAllocator allocator;
            size_t length;
        }

    @safe nothrow @nogc:

        string name;
        Slice!ChannelSpecification channels;
        double function(double, scope const State*) gammaApply;
        double function(double, scope const State*) gammaUnapply;
        Result!CIEXYZSample function(scope void[] input, scope const State*) toXYZ;
        ErrorResult function(scope void[] output, scope CIEXYZSample input, scope const State*) fromXYZ;

        void[] getExtraSpace() scope @system {
            void* base = &this;
            base += State.sizeof;
            return base[0 .. length];
        }

        @disable this(this);

        ColorSpace construct() scope @trusted {
            ColorSpace ret;
            ret.state = &this;
            return ret;
        }
    }

    State* allocate(RCAllocator allocator, size_t length) scope const @trusted {
        void[] data = allocator.makeArray!void(State.sizeof + length);

        State* ret = cast(State*)data.ptr;
        *ret = State.init;
        ret.allocator = allocator;
        ret.length = length;

        return ret;
    }
}

///
struct ChannelSpecification {
    ///
    string name;

    ///
    ubyte bits;
    ///
    bool isSigned;
    ///
    bool isWhole;

    ///
    double minimum, maximum;
    ///
    bool clampMinimum, clampMaximum;
    ///
    bool wrapAroundMinimum, wrapAroundMaximum;

@safe nothrow pure @nogc const:

    ///
    size_t numberOfBytes() scope {
        return cast(ubyte)((bits + 4) / 8f);
    }

    ///
    size_t fillDefault(scope void[] buffer) scope {
        size_t nob = numberOfBytes();
        assert(buffer.length >= nob);

        void handle(T)() @trusted nothrow @nogc {
            T* v = cast(T*)buffer.ptr;

            if (clampMinimum)
                *v = cast(T)minimum;
            else
                *v = 0;
        }

        if (!isWhole) {
            if (nob <= 4)
                handle!float;
            else
                handle!double;
        } else if (isSigned) {
            if (nob == 1)
                handle!byte;
            else if (nob == 2)
                handle!short;
            else if (nob == 3 || nob == 4)
                handle!int;
            else
                handle!long;
        } else {
            if (nob == 1)
                handle!ubyte;
            else if (nob == 2)
                handle!ushort;
            else if (nob == 3 || nob == 4)
                handle!uint;
            else
                handle!ulong;
        }

        return nob;
    }

    ///
    bool doesMatchType(T)() scope {
        size_t nob = numberOfBytes();

        if (!isWhole)
            return nob <= 4 ?  is(T == float) :  is(T == double);
        else if (isSigned) {
            switch (nob) {
            case 1:
                return is(T == byte);
            case 2:
                return is(T == short);
            case 3:
            case 4:
                return is(T == int);
            default:
                return is(T == long);
            }
        } else {
            switch (nob) {
            case 1:
                return is(T == ubyte);
            case 2:
                return is(T == ushort);
            case 3:
            case 4:
                return is(T == uint);
            default:
                return is(T == ulong);
            }
        }
    }
}

///
struct GammaNone {
}

///
struct GammaPower {
    ///
    double factor;

    ///
    double apply(double input) {
        return input ^^ factor;
    }

    ///
    double unapply(double input) {
        return input ^^ (1f / factor);
    }
}
