module sidero.colorimetry.colorspace.defs;
import sidero.base.allocators;
import sidero.base.errors;
import sidero.base.containers.readonlyslice;
import sidero.base.math.linear_algebra : Vec3d;

@safe nothrow @nogc:

/// This is a CIE XYZ color sample, it should not have any gamma applied.
struct CIEXYZSample {
    /// CIE XYZ X, Y, Z channels
    Vec3d sample;
    /// The white point for this sample
    CIEChromacityCoordinate whitePoint;
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

    /// Gamma will be automatically applied, does not clamp
    Result!CIEXYZSample toXYZ(scope void[] input) scope const {
        if (state is null || state.toXYZ is null)
            return typeof(return)(NullPointerException("toXYZ is not implemented"));
        return state.toXYZ(input, state);
    }

    /// Gamma will be automatically removed, does not clamp
    ErrorResult fromXYZ(scope void[] output, scope CIEXYZSample input) scope const {
        if (state is null || state.fromXYZ is null)
            return typeof(return)(NullPointerException("fromXYZ is not implemented"));
        return state.fromXYZ(output, input, state);
    }

    /// Adds auxiliary channels and implements swizzling
    Result!ColorSpace withChannels(string swizzle,
            scope Slice!ChannelSpecification auxillary = Slice!ChannelSpecification.init, RCAllocator allocator = RCAllocator.init) scope {
        import sidero.base.algorithm : startsWith;

        if (this.state is null)
            return typeof(return).init;
        if (allocator.isNull)
            allocator = globalAllocator();

        static bool isCompatibleSwizzle(string swizzle, scope Slice!ChannelSpecification current,
                Slice!ChannelSpecification auxillary, out size_t count) {
            // Requirements:
            // - No channels in auxillary can be close to each other
            // - No channels in auxillary can be close to current non-auxillary channels
            // - all channels in current that are !isAuxillary must be in swizzle

            foreach (i, aux1; auxillary) {
                foreach (j, aux2; auxillary) {
                    if (i == j)
                        continue;

                    if (aux1.name.length == 0 || aux2.name.length == 0)
                        return false;

                    if (aux1.name[0] == aux2.name[0])
                        return false;
                }

                foreach (c; current) {
                    if (c.name.length == 0)
                        return false;

                    if (c.isAuxillary)
                        continue;

                    if (aux1.name[0] == c.name[0])
                        return false;
                }
            }

            while (swizzle.length > 0) {
                ChannelSpecification channel;

                foreach (c; current) {
                    if (!c.isAuxillary && swizzle.startsWith(c.name)) {
                        channel = c;
                        swizzle = swizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                foreach (c; auxillary) {
                    if (swizzle.startsWith(c.name)) {
                        channel = c;
                        swizzle = swizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                foreach (c; current) {
                    if (c.isAuxillary && swizzle.startsWith(c.name)) {
                        channel = c;
                        swizzle = swizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                return false;
            FoundChannel:
                count++;
            }

            return swizzle.length == 0;
        }

        size_t numberOfIntoChannels;
        if (!isCompatibleSwizzle(swizzle, state.channels, auxillary, numberOfIntoChannels))
            return typeof(return)(MalformedInputException("Swizzle does not match color space and auxillary channels"));

        ChannelSpecification[] newChannels;

        {
            newChannels = allocator.makeArray!ChannelSpecification(numberOfIntoChannels);
            auto current = state.channels;
            size_t offsetIntoNewChannels;

            string temporarySwizzle = swizzle;
            while (temporarySwizzle.length > 0) {
                ChannelSpecification channel;

                foreach (c; current) {
                    if (!c.isAuxillary && temporarySwizzle.startsWith(c.name)) {
                        channel = c;
                        temporarySwizzle = temporarySwizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                foreach (c; auxillary) {
                    if (temporarySwizzle.startsWith(c.name)) {
                        channel = c;
                        channel.isAuxillary = true;
                        temporarySwizzle = temporarySwizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                foreach (c; current) {
                    if (c.isAuxillary && temporarySwizzle.startsWith(c.name)) {
                        channel = c;
                        temporarySwizzle = temporarySwizzle[c.name.length .. $];
                        goto FoundChannel;
                    }
                }

                assert(0);
            FoundChannel:
                // check that all channels are only in newChannels once
                foreach (nc; newChannels[0 .. offsetIntoNewChannels]) {
                    if (nc.name == channel.name) {
                        allocator.dispose(newChannels);
                        return typeof(return)(MalformedInputException("Multiple channels with same name in swizzle"));
                    }
                }

                newChannels[offsetIntoNewChannels] = channel;
                offsetIntoNewChannels++;
            }

            assert(offsetIntoNewChannels == numberOfIntoChannels);

            // check that all !isAuxillary channels in current are in swizzle
            foreach (c; current) {
                if (c.name.length == 0)
                    assert(0);

                if (c.isAuxillary)
                    continue;

                size_t found;

                foreach (nc; newChannels) {
                    if (nc.name == c.name)
                        found++;
                }

                if (found != 1) {
                    allocator.dispose(newChannels);
                    return typeof(return)(MalformedInputException("Missing colorspace channels from swizzle"));
                }
            }
        }

        ColorSpace ret;

        {
            ret = ColorSpace.allocate(allocator, state.length).construct;

            static foreach (i; 3 .. State.tupleof.length)
                ret.state.tupleof[i] = state.tupleof[i];

            state.copyModelFromTo(state, ret.state);
            ret.state.channels = Slice!ChannelSpecification(newChannels, allocator);
        }

        return typeof(return)(ret);
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
        void function(scope const State* copyFrom, scope State* copyTo) copyModelFromTo;
        double function(double, scope const State*) gammaApply;
        double function(double, scope const State*) gammaUnapply;
        Result!CIEXYZSample function(scope void[] input, scope const State*) toXYZ;
        ErrorResult function(scope void[] output, scope CIEXYZSample input, scope const State*) fromXYZ;

        const(void)[] getExtraSpace() scope const @system {
            const(void)* base = &this;
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

    static State* allocate(RCAllocator allocator, size_t length) @trusted {
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

    private bool isAuxillary;

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

    /// Will advance input value
    double extractSample01(scope ref void[] buffer) scope {
        double ret;

        size_t nob = numberOfBytes();
        assert(buffer.length >= nob);

        void handle(T)() @trusted nothrow @nogc {
            T* v = cast(T*)buffer.ptr;

            ret = cast(double)*v;
            ret -= minimum;
            ret = (maximum - minimum) / ret;

            buffer = buffer[T.sizeof .. $];
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

        return ret;
    }

    /// Will advance input value
    void store01Sample(scope ref void[] output, double input) scope {
        size_t nob = numberOfBytes();
        assert(output.length >= nob);

        void handle(T)() @trusted nothrow @nogc {
            T* v = cast(T*)output.ptr;

            input *= maximum - minimum;
            input += minimum;
            *v = cast(T)input;

            output = output[T.sizeof .. $];
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
    }

    /// Will advance input value
    void storeDefaultSample(scope ref void[] output) {
        size_t advance = fillDefault(output);
        output = output[advance .. $];
    }
}

///
struct GammaNone {
}

///
struct GammaPower {
    ///
    double factor;

@safe nothrow @nogc:

    ///
    double apply(double input) {
        return input ^^ factor;
    }

    ///
    double unapply(double input) {
        return input ^^ (1f / factor);
    }
}
