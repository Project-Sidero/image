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
    this(scope return void[] data, scope return void* user, scope return RCHandle rcHandle) scope @trusted {
        assert(data !is null);
        assert(rcHandle !is null);

        this.data = data;
        this._user = user;
        this.rcHandler = rcHandle;
    }

    ///
    this(scope return ColorSpace colorSpace, RCAllocator allocator = RCAllocator.init) scope @trusted {
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

            foreach (channel; this._colorSpace.channels) {
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
    ColorSpace colorSpace() scope {
        return _colorSpace;
    }

    ///
    ResultReference!T channel(T)(string name) @trusted {
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
    PixelReference swizzle(scope string names, scope Slice!ChannelSpecification auxillary = Slice!ChannelSpecification.init,
            RCAllocator allocator = RCAllocator.init) scope {

        if (isNull)
            return typeof(return)(NullPointerException);
        if (allocator.isNull)
            allocator = globalAllocator();

        ColorSpace newColorSpace = this._colorSpace.withChannels(names, auxillary, allocator);
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
    PixelReference convertTo(ColorSpace newColorSpace, RCAllocator allocator = RCAllocator.init) @trusted {
        if (isNull)
            return typeof(return)(NullPointerException);

        Pixel ret = Pixel(newColorSpace, allocator);

        {
            auto asXYZ = _colorSpace.toXYZ(data);
            if (!asXYZ)
                return typeof(return)(asXYZ.error);

            auto result = newColorSpace.fromXYZ(ret.data, asXYZ.get);
            if (!result)
                return typeof(return)(result.error);
        }

        {
            void[] into = ret.data, from = this.data;
            auto intoChannels = newColorSpace.channels, fromChannels = _colorSpace.channels;

            foreach (fromChannel; fromChannels) {
                double got = fromChannel.extractSample01(from);

                if (fromChannel.isAuxillary) {
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

        return typeof(return)(ret);
    }

    ///
    String_UTF8 toString(RCAllocator allocator = globalAllocator()) @trusted {
        StringBuilder_UTF8 ret = StringBuilder_UTF8(allocator);
        toString(ret);
        return ret.asReadOnly;
    }

    ///
    void toString(Sink)(scope ref Sink sink) @trusted {
        if (this.isNull) {
            sink ~= "null";
            return;
        }

        auto colorSpace = this.colorSpace;
        void[] temp = data;

        foreach (i, channel; colorSpace.channels) {
            if (i > 0)
                sink ~= ", ";

            double value = channel.extractSample01(temp);
            sink.formattedWrite(String_ASCII("%s"), channel.sample01AsRange(value));
        }
    }

    ///
    String_UTF8 toStringPretty(RCAllocator allocator = globalAllocator()) @trusted {
        StringBuilder_UTF8 ret = StringBuilder_UTF8(allocator);
        toStringPretty(ret);
        return ret.asReadOnly;
    }

    ///
    void toStringPretty(Sink)(scope ref Sink sink) {
        if (this.isNull) {
            sink ~= "null";
            return;
        }

        auto colorSpace = this.colorSpace;
        sink.formattedWrite(String_ASCII("%s("), colorSpace.name);

        void[] temp = data;

        foreach (i, channel; colorSpace.channels) {
            if (i > 0)
                sink ~= ", ";

            double value = channel.extractSample01(temp);
            sink.formattedWrite(String_ASCII("%s: %s"), channel.name, channel.sample01AsRange(value));
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
