module sidero.image.internal.state;
import sidero.image.defs : CImage, Image;
import sidero.image.metadata.defs;
import sidero.colorimetry.colorspace;
import sidero.colorimetry.pixel;
import sidero.base.allocators;
import sidero.base.containers.map.concurrenthashmap;
import sidero.base.errors;

export:

/**
 See: https://dl.acm.org/doi/abs/10.1145/965145.801296 for more information on how the image representation works
 A language for bitmap manipulation - Guibas, Leo J. and Stolfi, Jorge
*/
struct ImageRef {
    ImageState* state;

    ptrdiff_t pixelStride, rowStride;
    void* dataBegin;
    size_t width, height;

export @safe nothrow @nogc:

    @disable this(int value) const;

    @disable this(ref const ImageRef other) const;

    @disable void opAssign(ref ImageRef other) const;
    @disable void opAssign(ImageRef other) const;

    @disable auto opCast(T)();

    this(ImageState* state) scope {
        import core.atomic : atomicOp;

        atomicOp!"+="(state.refCount, 1);

        this.state = state;
        this.pixelStride = state.pixelStride;
        this.rowStride = state.rowStride;
        this.dataBegin = &state.data[0];
        this.width = state.width;
        this.height = state.height;
    }

    this(scope return ref ImageRef other) scope @trusted {
        foreach (i, v; other.tupleof)
            this.tupleof[i] = v;

        addRef();
    }

    @disable this(this);

    ~this() scope {
        removeRef();
    }

    void opAssign(ref ImageRef other) scope {
        __ctor(other);
    }

    void opAssign(ImageRef other) scope {
        __ctor(other);
    }

    bool isNull() scope const {
        return state is null;
    }

    void rc(bool addRef, scope void* user) {
        if (addRef)
            this.addRef;
        else
            removeRef;
    }

    void addRef() scope {
        import core.atomic : atomicOp;

        if (!isNull)
            atomicOp!"+="(state.refCount, 1);
    }

    void removeRef() scope @trusted {
        import core.atomic : atomicOp;

        if (isNull)
            return;

        if (atomicOp!"-="(state.refCount, 1) == 0) {
            RCAllocator alloc = state.allocator;
            alloc.dispose(state);
            state = null;
        }
    }

    void offset(size_t x, size_t y) scope @trusted {
        if (isNull)
            return;

        assert(x < this.width);
        assert(y < this.height);

        this.dataBegin += x * this.pixelStride;
        this.dataBegin += y * this.rowStride;

        this.width -= x;
        this.height -= y;
    }

    void subset(size_t width, size_t height) scope {
        if (isNull)
            return;

        assert(width < this.width);
        assert(height < this.height);

        this.width = width;
        this.height = height;
    }

    ImageRef dup(RCAllocator allocator = RCAllocator.init, ptrdiff_t newAlignment = -1, bool keepOldMetaData = false) scope {
        if (isNull)
            return ImageRef.init;
        else if (allocator.isNull)
            allocator = state.allocator;

        if (newAlignment < 0)
            newAlignment = state.rowAlignment;

        size_t x, y;
        state.subsetSizeAndOffsetFromThis(this, x, y);

        return ImageRef(state.dup(allocator, [x, y], [this.width, this.height], newAlignment, state.colorSpace,
                keepOldMetaData, this.pixelStride < 0, this.rowStride < 0));
    }

    ImageRef dup(ColorSpace colorSpace, RCAllocator allocator = RCAllocator.init, ptrdiff_t newAlignment = -1, bool keepOldMetaData = false) scope {
        if (isNull || colorSpace.isNull)
            return ImageRef.init;
        else if (allocator.isNull)
            allocator = state.allocator;

        if (newAlignment < 0)
            newAlignment = state.rowAlignment;

        size_t x, y;
        state.subsetSizeAndOffsetFromThis(this, x, y);

        return ImageRef(state.dup(allocator, [x, y], [this.width, this.height], newAlignment, colorSpace,
                keepOldMetaData, this.pixelStride < 0, this.rowStride < 0));
    }

    void flipHorizontal() scope @trusted {
        if (isNull)
            return;

        this.dataBegin += (this.width - 1) * this.pixelStride;
        this.pixelStride *= -1;
    }

    void flipVertical() scope @trusted {
        if (isNull)
            return;

        this.dataBegin += (this.height - 1) * this.rowStride;
        this.rowStride *= -1;
    }

    bool containsMetaData(Type)() scope {
        if (isNull)
            return false;

        return state.containsMetaData!Type;
    }

    void removeMetaData(Type)() scope {
        if (isNull)
            return;

        state.removeMetaData!Type;
    }

    ImageMetaData!Type getMetaData(Type)() scope @trusted {
        if (isNull)
            return typeof(return).init;

        Image ret;
        ret.imageRef = this;
        ret.colorSpace = state.colorSpace;

        return ImageMetaData!Type(this.state.acquireMetaData!Type, ret);
    }

    size_t metaDataCount() scope {
        if (isNull)
            return 0;

        return this.state.metaDataCount;
    }

    CImage raw() scope @system {
        import std.math : abs;

        CImage ret;

        () @system {
            ret = CImage(this.dataBegin, this.width, this.height, abs(this.pixelStride), this.pixelStride, this.rowStride);
        }();

        return ret;
    }
}

struct ImageState {
    shared ptrdiff_t refCount;
    RCAllocator allocator;

    void[] data;
    ptrdiff_t rowStride, pixelStride; // this may be negative, but it won't be internally to ImageState!!!
    size_t rowPadding, rowAlignment;
    size_t width, height;

    ColorSpace colorSpace;

    ConcurrentHashMap!(string, MetaDataStorage) metadata;

    @disable this(this);

export @safe nothrow @nogc:

    this(RCAllocator newAllocator, ColorSpace colorSpace, size_t[2] size, size_t alignment = 0) scope @trusted {
        this.allocator = newAllocator;
        this.metadata = ConcurrentHashMap!(string, MetaDataStorage)(newAllocator);

        this.width = size[0];
        this.height = size[1];
        this.colorSpace = colorSpace;

        foreach (cspec; colorSpace.channels)
            this.pixelStride += cspec.numberOfBytes;

        this.configureAsAlignment(alignment);

        //

        void* temp = this.data.ptr;
        void[] firstRow = temp[0 .. this.rowStride];

        foreach (cspec; colorSpace.channels) {
            temp += cspec.fillDefault(temp[0 .. this.pixelStride]);
        }

        foreach (x; 1 .. this.width) {
            foreach (i, ref v; cast(ubyte[])temp[0 .. this.pixelStride])
                v = (cast(ubyte[])firstRow[0 .. this.pixelStride])[i];
            temp += this.pixelStride;
        }

        //

        temp = this.data.ptr + this.rowStride;
        foreach (y; 1 .. this.height) {
            // firstRow could be aligned, which is VERY important if you want a vectorized copy!
            // which is why firstRow is is the row length, and not actual pixel length

            foreach (i, ref v; cast(ubyte[])temp[0 .. this.rowStride])
                v = (cast(ubyte[])firstRow[0 .. this.rowStride])[i];
            temp += this.rowStride;
        }
    }

    ~this() scope @trusted {
        allocator.dispose(data);
    }

    // GL_UNPACK_ROW_LENGTH is the original width, GL_UNPACK_SKIP_PIXELS for the LHS to skip pixels

    ImageState* dup(RCAllocator newAllocator, size_t[2] start, size_t[2] size, size_t alignment, ColorSpace newColorSpace,
            bool keepOldMetaData, bool flipHorizontal, bool flipVertical) scope @trusted {

        ImageState* ret = newAllocator.make!ImageState(newAllocator, newColorSpace, size, alignment);

        if (keepOldMetaData)
            ret.metadata = this.metadata;

        void* ptrToDestination = ret.data.ptr;
        ptrdiff_t destinationRowStride = ret.rowStride, destinationPixelStride = ret.pixelStride;
        const destinationPixelSize = ret.pixelStride, destinationRowSize = this.rowStride;

        if (flipVertical) {
            ptrToDestination += (ret.height - 1) * destinationRowStride;
            destinationRowStride *= -1;
        }

        if (flipHorizontal) {
            ptrToDestination += (ret.width - 1) * destinationPixelStride;
            destinationPixelStride *= -1;
        }

        void* ptrToSource = this.data.ptr + (start[0] * this.pixelStride) + (start[1] * this.rowStride);
        const sourceRowStride = this.rowStride, sourcePixelStride = this.pixelStride, sourcePixelSize = this.pixelStride,
            sourceRowSize = this.rowStride;

        void handle(bool sameColorSpace, bool flipHorizontal = false)() {
            foreach (y; 0 .. size[1]) {
                void* rowDest = ptrToDestination;
                void* rowSrc = ptrToSource;

                static if (sameColorSpace) {
                    foreach (x; 0 .. size[0]) {
                        rowSrc += sourcePixelStride;
                        rowDest += destinationPixelStride;

                        void[] pixelInto = rowDest[0 .. destinationPixelSize], pixelFrom = rowSrc[0 .. sourcePixelSize];

                        Pixel destinationPixel = Pixel(pixelInto, ret.colorSpace, null, null),
                            sourcePixel = Pixel(pixelFrom, this.colorSpace, null, null);
                        sourcePixel.convertInto(destinationPixel);
                    }
                } else static if (flipHorizontal) {
                    size_t i = sourceRowSize - 1;
                    foreach (ref v; cast(ubyte[])rowDest[0 .. destinationRowSize])
                        v = (cast(ubyte*)rowSrc)[i--];
                } else {
                    foreach (i, ref v; cast(ubyte[])rowDest[0 .. destinationRowSize])
                        v = (cast(ubyte*)rowSrc)[i];
                }

                ptrToDestination += destinationRowStride;
                ptrToSource += sourceRowStride;
            }
        }

        if (this.colorSpace == newColorSpace) {
            assert(ret.pixelStride == this.pixelStride);
            handle!true;
        } else {
            if (flipHorizontal)
                handle!(false, true);
            else
                handle!(false, false);
        }

        return ret;
    }

    void subsetSizeAndOffsetFromThis(scope const ref ImageRef imageRef, ref size_t x, ref size_t y) scope {
        size_t fromZero = imageRef.dataBegin - &this.data[0];

        if (imageRef.rowStride < 0)
            fromZero -= (imageRef.height - 1) * this.rowStride;
        if (imageRef.pixelStride < 0)
            fromZero -= (imageRef.width - 1) * this.pixelStride;

        y = fromZero / this.rowStride;
        fromZero %= this.rowStride;
        x = fromZero / this.pixelStride;
    }

    bool containsMetaData(Type)() scope @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        return keyId in metadata;
    }

    void removeMetaData(Type)() scope @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        metadata.remove(keyId);
    }

    size_t metaDataCount() scope {
        return metadata.length;
    }

    MetaDataStorageReference acquireMetaData(Type)() scope @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        auto ret = metadata[keyId];

        if (ret)
            return ret;

        Type* temp = allocator.make!Type;
        MetaDataStorage.OnDeallocate onDeallocate;

        static if (__traits(compiles, { onDeallocate = &temp.__dtor; })) {
            onDeallocate = &temp.__dtor;
        }

        metadata[keyId] = MetaDataStorage(allocator, (cast(void*)temp)[0 .. Type.sizeof], onDeallocate);
        return metadata[keyId];
    }

    /*
        It is recommended to allocate the image storage to an alignment of 4 bytes per row regardless of usage
        This will assist vectorization
    */
    void configureAsAlignment(size_t alignment = 4) scope @trusted {
        // ensures all rows have an alignment of width * components % alignment == 0
        // this covers GL_UNPACK_ALIGNMENT

        assert(data.ptr is null);

        this.rowStride = this.width * this.pixelStride;
        this.rowAlignment = alignment;

        if (alignment > 0)
            this.rowPadding = alignment - (this.rowStride % alignment);

        if (this.rowPadding == alignment)
            this.rowPadding = 0;
        else
            this.rowStride += this.rowPadding;

        this.data = allocator.makeArray!ubyte(this.rowStride * this.height);
    }
}

unittest {
    import sidero.colorimetry.colorspace;
    import sidero.colorimetry.illuminants;
    import sidero.colorimetry.colorspace.cie.xyz;
    import sidero.base.allocators;

    ImageState original = ImageState(globalAllocator(), cie_XYZ(32, Illuminants.E_2Degrees), [10, 10], 16);

    assert(original.data.ptr !is null);
    assert(original.width == 10);
    assert(original.height == 10);
    assert(original.pixelStride == 3 * 4);

    ImageState* copied = original.dup(globalAllocator(), [2, 2], [6, 7], 0, original.colorSpace, true, false, false);
    assert(copied.width == 6);
    assert(copied.height == 7);
    assert(copied.pixelStride == original.pixelStride);
}

alias MetaDataStorageReference = ResultReference!MetaDataStorage;

struct MetaDataStorage {
    alias OnDeallocate = void function(scope void[]) @safe nothrow @nogc;

    private {
        void[] data;
        RCAllocator allocator;
        OnDeallocate onDeallocateDel;
    }

export @safe nothrow @nogc:

    this(RCAllocator allocator, scope return void[] data, scope return OnDeallocate onDeallocateDel) scope @trusted {
        this.allocator = allocator;
        this.data = data;
        this.onDeallocateDel = onDeallocateDel;
    }

    this(scope ref MetaDataStorage other) scope @trusted {
        this.data = other.data;
        this.allocator = other.allocator;
        this.onDeallocateDel = other.onDeallocateDel;

        other.allocator = RCAllocator.init;
    }

    @disable this(this);

    ~this() scope @trusted {
        if (!allocator.isNull && data !is null) {
            if (this.onDeallocateDel !is null)
                this.onDeallocateDel(data);

            allocator.dispose(data);
        }
    }

    void opAssign(scope ref MetaDataStorage other) scope {
        __ctor(other);
    }

    bool isNull() scope const {
        return data is null;
    }

    T* getMetaDataRef(T)() scope @trusted {
        assert(data !is null);
        return cast(T*)data;
    }

    string toString() scope const {
        return isNull ? "null" : "has value";
    }
}
