module sidero.image.internal.state;
import sidero.colorimetry.colorspace;
import sidero.colorimetry.pixel;
import sidero.base.allocators;
import sidero.base.containers.map.concurrenthashmap;
import sidero.base.errors;

export:

struct ImageRef {
    ImageState* state;

    ptrdiff_t pixelStride, rowStride;
    void* dataBegin;
    size_t width, height;
}

struct MetaDataStorage {
}

struct ImageState {
    ptrdiff_t refCount;
    RCAllocator allocator;

    void[] data;
    ptrdiff_t rowStride, pixelStride; // this may be negative, but it won't be internally to ImageState!!!
    size_t rowPadding, rowAlignment;
    size_t width, height;

    ColorSpace colorSpace;

    ConcurrentHashMap!(string, MetaDataStorage) metadata;

    @disable this(this);

export @safe nothrow @nogc:

    this(RCAllocator newAllocator, ColorSpace colorSpace, size_t[2] size, size_t alignment = 0) @trusted {
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

    ~this() @trusted {
        allocator.dispose(data);
    }

    // GL_UNPACK_ROW_LENGTH is the original width, GL_UNPACK_SKIP_PIXELS for the LHS to skip pixels

    ImageState* dup(RCAllocator newAllocator, size_t[2] start, size_t[2] size, size_t alignment,
        ColorSpace newColorSpace = ColorSpace.init, bool keepOldMetaData = false) @trusted {

        ImageState* ret = newAllocator.make!ImageState(newAllocator, newColorSpace, size, alignment);

        if (keepOldMetaData)
            ret.metadata = this.metadata;

        void* source = this.data.ptr + (start[0] * this.pixelStride);
        void* destination = ret.data.ptr;

        if (this.colorSpace == newColorSpace) {
            assert(ret.pixelStride == this.pixelStride);

            // fast track copy
            foreach (y; start[1] .. start[1] + size[1]) {
                void* rowDest = destination;
                void* sourceDest = source;

                foreach (x; start[0] .. start[0] + size[0]) {
                    foreach(i, ref v; cast(ubyte[])rowDest[0 .. this.pixelStride])
                        v = (cast(ubyte*)sourceDest)[i];

                    sourceDest += this.pixelStride;
                    rowDest += ret.pixelStride;
                }

                source += this.rowStride;
                destination += ret.rowStride;
            }
        } else {
            // Unfortunately we have to do a slow copy over with color conversion.
            // We don't match, although we may have same core channel, something isn't right anyway.

            foreach (y; start[1] .. start[1] + size[1]) {
                void* rowDest = destination;
                void* sourceDest = source;

                foreach (x; start[0] .. start[0] + size[0]) {
                    void[] pixelInto = rowDest[0 .. ret.pixelStride], pixelFrom = source[0 .. this.pixelStride];

                    Pixel sourcePixel = Pixel(pixelFrom, null, null), destinationPixel = Pixel(pixelInto, null, null);
                    sourcePixel.convertInto(destinationPixel);

                    sourceDest += this.pixelStride;
                    rowDest += ret.pixelStride;
                }

                source += this.rowStride;
                destination += ret.rowStride;
            }
        }

        return ret;
    }

    void subsetSizeAndOffsetFromThis(ref const ImageRef imageRef, out size_t x, out size_t y) @safe nothrow @nogc {
        size_t fromZero = imageRef.dataBegin - &this.data[0];

        if (imageRef.rowStride < 0)
            fromZero -= (imageRef.height - 1) * this.rowStride;
        if (imageRef.pixelStride < 0)
            fromZero -= (imageRef.width - 1) * this.pixelStride;

        y = fromZero / this.rowStride;
        fromZero %= this.rowStride;
        x = fromZero / this.pixelStride;
    }

    bool containsMetaData(Type)() @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        return keyId in metadata;
    }

    void removeMetaData(Type)() @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        metadata.remove(keyId);
    }

    size_t metaDataCount() @safe {
        return metadata.length;
    }

    ResultReference!MetaDataStorage acquireMetaData(Type)() @trusted {
        import sidero.base.traits : fullyQualifiedName;

        enum keyId = fullyQualifiedName!Type;
        auto ret = metadata[keyId];

        if (!ret.isNull)
            return ret;

        Type* temp = allocator.make!Type;
        metadata[keyId] = MetaDataStorage(allocator, temp);
        return metadata[keyId];
    }

    /*
        It is recommended to allocate the image storage to an alignment of 4 bytes per row regardless of usage
        This will assist vectorization
    */
    void configureAsAlignment(size_t alignment = 4) @trusted {
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
