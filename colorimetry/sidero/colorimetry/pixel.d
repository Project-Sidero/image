module sidero.colorimetry.pixel;
import sidero.colorimetry.colorspace;
import sidero.base.allocators;
import sidero.base.errors;
import sidero.base.containers.readonlyslice;
import sidero.base.text;

///
alias PixelReference = Result!Pixel;

///
struct Pixel {
    ///
    alias RCHandle = void delegate(bool addRef, scope void* _user) @safe nothrow @nogc;

    private {
        import std.meta : allSatisfy;
        import std.traits : isNumeric;

        void[] data;
        ColorSpace _colorSpace;
        void* _user;
        RCHandle rcHandler;

        static struct Internal {
            RCAllocator allocator;
            shared ptrdiff_t refCount;
            void[] data;

        @safe nothrow @nogc:

            void rc(bool addRef, scope void* user) @trusted {
                import core.atomic : atomicOp;

                if (addRef)
                    atomicOp!"+="(refCount, 1);
                else if (atomicOp!"-="(refCount, 1) == 0) {
                    RCAllocator allocator = this.allocator;
                    allocator.dispose(data);
                    allocator.dispose(&this);
                }
            }

            bool opEquals(scope Internal other) const {
                return data.ptr is other.data.ptr;
            }
        }
    }

@safe nothrow @nogc:

    ///
    bool isNull() scope {
        return this.data is null;
    }

    ///
    this(return scope void[] data, ColorSpace colorSpace, return scope void* user, return scope RCHandle rcHandle) scope @trusted {
        assert(data !is null);

        this.data = data;
        this._colorSpace = colorSpace;
        this._user = user;
        this.rcHandler = rcHandle;
    }

    ///
    this(return scope ColorSpace colorSpace, RCAllocator allocator = RCAllocator.init) scope @trusted {
        if (colorSpace.isNull)
            return;
        if (allocator.isNull)
            allocator = globalAllocator();

        size_t size;
        auto channels = colorSpace.channels;
        foreach (c; channels) {
            size += c.numberOfBytes;
        }

        this.data = allocator.makeArray!void(size);
        this._colorSpace = colorSpace;

        Internal* internal = allocator.make!Internal(allocator, 1, this.data);
        this.rcHandler = cast(RCHandle)&internal.rc;

        {
            void[] temp = this.data;

            foreach (channel; channels) {
                channel.storeDefaultSample(temp);
            }
        }
    }

    ///
    this(scope ref Pixel other) scope @trusted {
        static foreach (i; 0 .. this.tupleof.length)
            this.tupleof[i] = other.tupleof[i];

        if (this.rcHandler !is null)
            this.rcHandler(true, this._user);
    }

    ///
    ~this() scope @trusted {
        if (this.rcHandler !is null)
            this.rcHandler(false, this._user);
    }

    ///
    ColorSpace colorSpace() scope @trusted {
        return _colorSpace;
    }

    ///
    ResultReference!T channel(T)(scope string name) scope @trusted {
        size_t offset, length;

        foreach (c; _colorSpace.channels) {
            length = c.numberOfBytes;

            if (c.name == name) {
                if (!c.doesMatchType!T)
                    return typeof(return)(MalformedInputException("Given type does not match channel"));
                else if (this.data.length < offset + length)
                    return typeof(return)(RangeException("Pixel data does not match channel description in length"));

                void[] slice = this.data[offset .. offset + length];
                this.rcHandler(true, _user);
                return typeof(return)(cast(T*)slice.ptr, _user, rcHandler);
            }

            offset += length;
        }

        return typeof(return)(MalformedInputException("No channel given name"));
    }

    ///
    Result!double channel01(scope string name) scope @trusted {
        size_t offset, length;

        foreach (c; _colorSpace.channels) {
            length = c.numberOfBytes;

            if (c.name == name) {
                if (this.data.length < offset + length)
                    return typeof(return)(RangeException("Pixel data does not match channel description in length"));

                void[] slice = this.data[offset .. offset + length];
                return typeof(return)(c.extractSample01(slice));
            }

            offset += length;
        }

        return typeof(return)(MalformedInputException("No channel given name"));
    }

    ///
    ErrorResult channel01(scope string name, double newValue) scope @trusted {
        size_t offset, length;

        foreach (c; _colorSpace.channels) {
            length = c.numberOfBytes;

            if (c.name == name) {
                if (this.data.length < offset + length)
                    return typeof(return)(RangeException("Pixel data does not match channel description in length"));

                void[] slice = this.data[offset .. offset + length];
                c.store01Sample(slice, newValue);
                return typeof(return)();
            }

            offset += length;
        }

        return typeof(return)(MalformedInputException("No channel given name"));
    }

    ///
    Result!CIEXYZSample asXYZ() scope @trusted {
        return _colorSpace.toXYZ(this.data);
    }

    ///
    PixelReference swizzle(scope string names, scope Slice!ChannelSpecification auxiliary = Slice!ChannelSpecification.init,
            RCAllocator allocator = RCAllocator.init) scope {

        if (isNull)
            return typeof(return)(NullPointerException);
        if (allocator.isNull)
            allocator = globalAllocator();

        ColorSpace newColorSpace = this._colorSpace.withChannels(names, auxiliary, allocator);
        Pixel ret = Pixel(newColorSpace, allocator);

        void[] tempOutput = ret.data;
        foreach (destChannel; newColorSpace.channels) {
            bool found;
            double value;

            {
                void[] tempInput = this.data;

                foreach (srcChannel; _colorSpace.channels) {
                    value = srcChannel.extractSample01(tempInput);

                    if (destChannel.name is srcChannel.name) {
                        found = true;
                        break;
                    }
                }
            }

            if (found)
                destChannel.store01Sample(tempOutput, value);
            else
                destChannel.storeDefaultSample(tempOutput);
        }

        return typeof(return)(ret);
    }

    ///
    PixelReference convertTo(ColorSpace newColorSpace, RCAllocator allocator = RCAllocator.init) scope @trusted {
        Pixel ret = Pixel(newColorSpace, allocator);
        ErrorResult result = convertInto(ret);

        if (result)
            return typeof(return)(ret);
        else
            return typeof(return)(result.getError);
    }

    ///
    ErrorResult convertInto(scope ref Pixel pixel) scope @trusted {
        if (isNull || pixel.isNull)
            return typeof(return)(NullPointerException);

        {
            auto asXYZ = _colorSpace.toXYZ(data);
            if (!asXYZ)
                return typeof(return)(asXYZ.getError);

            auto result = pixel.colorSpace.fromXYZ(pixel.data, asXYZ.get);
            if (!result)
                return typeof(return)(result.getError);
        }

        {
            void[] into = pixel.data, from = this.data;
            auto intoChannels = pixel.colorSpace.channels, fromChannels = _colorSpace.channels;

            foreach (fromChannel; fromChannels) {
                double got = fromChannel.extractSample01(from);

                if (fromChannel.isAuxiliary) {
                    auto tempChannels = intoChannels;
                    void[] tempInto = into;

                    foreach (intoChannel; tempChannels) {
                        if (fromChannel.name == intoChannel.name) {
                            intoChannel.store01Sample(tempInto, got);
                            break;
                        } else {
                            tempInto = tempInto[intoChannel.numberOfBytes .. $];
                        }
                    }
                }
            }
        }

        return typeof(return)();
    }

    ///
    ErrorResult set(Values...)(Values values) scope if (allSatisfy!(isNumeric, Values)) {
        if (isNull)
            return typeof(return)(NullPointerException);

        auto channels = _colorSpace.channels;
        if (channels.length != values.length)
            return typeof(return)(MalformedInputException("Number of channels does not match inputs"));

        void[] temp = data;

        static foreach (Value; values) {
            {
                assert(!channels.empty);
                auto spec = channels.front;
                assert(spec);

                double value01 = spec.sampleRangeAs01(cast(double)Value);
                spec.store01Sample(temp, value01);

                channels.popFront;
            }
        }

        return ErrorResult.init;
    }

    ///
    void opAssign(scope CIEXYZSample cieXYZSample) scope @trusted {
        if (isNull)
            return;

        cast(void)this.colorSpace.fromXYZ(this.data, cieXYZSample);
    }

    ///
    Pixel dup(RCAllocator allocator = RCAllocator.init) scope @trusted {
        if (isNull)
            return Pixel.init;

        ColorSpace colorSpace = this._colorSpace;
        Pixel ret = Pixel(colorSpace, allocator);

        foreach (i, b; cast(ubyte[])this.data)
            (cast(ubyte[])ret.data)[i] = b;

        return ret;
    }

    ///
    String_UTF8 toString(RCAllocator allocator = globalAllocator()) scope @trusted {
        StringBuilder_UTF8 ret = StringBuilder_UTF8(allocator);
        toString(ret);
        return ret.asReadOnly;
    }

    ///
    void toString(Sink)(scope ref Sink sink) scope @trusted {
        if (this.isNull) {
            sink ~= "null";
            return;
        }

        auto colorSpace = this.colorSpace;
        void[] temp = data;

        foreach (i, channel; colorSpace.channels) {
            if (i > 0)
                sink ~= ", ";

            const before = channel.extractSample01(temp);
            const after = channel.sample01AsRange(before);
            sink.formattedWrite("{:s}", after);
        }
    }

    ///
    String_UTF8 toStringPretty(RCAllocator allocator = globalAllocator()) scope @trusted {
        StringBuilder_UTF8 ret = StringBuilder_UTF8(allocator);
        toStringPretty(ret);
        return ret.asReadOnly;
    }

    ///
    void toStringPretty(Sink)(scope ref Sink sink) scope {
        if (this.isNull) {
            sink ~= "null";
            return;
        }

        auto colorSpace = this.colorSpace;
        sink.formattedWrite("{:s}(", colorSpace.name);

        void[] temp = data;

        foreach (i, channel; colorSpace.channels) {
            if (i > 0)
                sink ~= ", ";

            const before = channel.extractSample01(temp);
            const after = channel.sample01AsRange(before);
            sink.formattedWrite("{:s}: {:s}", channel.name, after);
        }

        sink ~= ")";
    }

    ///
    bool opEquals(scope Pixel other) scope const {
        return _colorSpace == other._colorSpace && _colorSpace.compareSamples(this.data, other.data) == 0;
    }

    ///
    int opCmp(scope Pixel other) scope const {
        if (_colorSpace < other._colorSpace)
            return -1;
        else if (_colorSpace > other._colorSpace)
            return 1;
        else
            return _colorSpace.compareSamples(this.data, other.data);
    }
}
