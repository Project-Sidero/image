module sidero.image.defs;
import sidero.image.metadata.defs;
import sidero.colorimetry.colorspace;
import sidero.colorimetry.pixel;
import sidero.base.allocators;
import sidero.base.errors;

export:

///
struct CImage {
    ///
    void* dataBegin;
    ///
    size_t width, height, pixelChannelsSize;
    ///
    ptrdiff_t pixelPitch, rowStride;

export @safe nothrow @nogc:

    ///
    bool isNull() scope const {
        return dataBegin is null || width == 0 || height == 0 || pixelChannelsSize == 0 || pixelPitch == 0 || rowStride == 0;
    }
}

///
struct ImageSlice(int op) {
    ///
    size_t start, end;
}

///
struct Image {
    package(sidero.image) {
        import sidero.image.internal.state;

        ImageRef imageRef;
        ColorSpace colorSpace;
    }

export @safe nothrow @nogc:

    ///
    bool isNull() scope const {
        return imageRef.isNull;
    }

    ///
    void nullify() scope {
        imageRef = ImageRef.init;
    }

    ///
    this(scope return ref Image other) scope @trusted {
        foreach (i, v; other.tupleof)
            this.tupleof[i] = v;
    }

    ///
    this(ColorSpace colorSpace, size_t width, size_t height, RCAllocator allocator = globalAllocator(), size_t alignment = 4) scope @trusted {
        imageRef = ImageRef(allocator.make!ImageState(allocator, colorSpace, cast(size_t[2])[width, height], alignment));
        this.colorSpace = colorSpace;
    }

    ///
    size_t opDollar(int op)() scope if (op == 0 || op == 1) {
        if (isNull)
            return 0;

        static if (op == 0)
            return imageRef.width;
        else
            return imageRef.height;
    }

    ///
    ImageSlice!op opSlice(int op)(size_t start, size_t end) scope if (op == 0 || op == 1) {
        if (isNull)
            return typeof(return).init;

        static if (op == 0) {
            if (start < end && end < imageRef.width) {
            } else {
                return typeof(return).init;
            }
        } else static if (op == 1) {
            if (start < end && end < imageRef.height) {
            } else {
                return typeof(return).init;
            }
        }

        return typeof(return)(start, end);
    }

    ///
    Result!Image opIndex(ImageSlice!0 x, ImageSlice!1 y) scope @trusted {
        if (isNull)
            return typeof(return)(NullPointerException);

        if (x.start < x.end && x.end < imageRef.width) {
        } else {
            return typeof(return)(RangeException("Start and end must be smaller than width"));
        }

        if (y.start < y.end && y.end < imageRef.height) {
        } else {
            return typeof(return)(RangeException("Start and end must be smaller than height"));
        }

        Image ret = this;

        ret.imageRef.offset(x.start, y.start);
        ret.imageRef.subset(x.end - x.start, y.end - y.start);

        return typeof(return)(ret);
    }

    ///
    Image dup(RCAllocator allocator = RCAllocator(), bool keepOldMetaData = false) scope @trusted {
        if (isNull)
            return Image.init;

        Image ret;
        ret.imageRef = imageRef.dup(allocator, -1, keepOldMetaData);
        ret.colorSpace = this.colorSpace;

        return ret;
    }

    ///
    Image dup(ColorSpace newColorSpace, RCAllocator allocator = RCAllocator(), bool keepOldMetaData = false) scope @trusted {
        if (isNull)
            return Image.init;

        Image ret;
        ret.imageRef = imageRef.dup(newColorSpace, allocator, -1, keepOldMetaData);
        ret.colorSpace = newColorSpace;

        return ret;
    }

    ///
    Image original() scope @trusted {
        if (isNull)
            return Image.init;

        Image ret;
        ret.imageRef = ImageRef(imageRef.state);
        ret.colorSpace = this.colorSpace;

        return ret;
    }

    ///
    PixelReference opIndex(size_t x, size_t y) scope return @trusted {
        if (isNull)
            return typeof(return)(NullPointerException);

        assert(x < imageRef.width);
        assert(y < imageRef.height);

        void* location = imageRef.dataBegin + (imageRef.rowStride * y) + (imageRef.pixelStride * x);
        const size = imageRef.pixelStride < 0 ? -imageRef.pixelStride : imageRef.pixelStride;
        void[] array = location[0 .. size];

        return typeof(return)(Pixel(array, this.colorSpace, cast(void*)null, &imageRef.rc));
    }

    ///
    void flipHorizontal() scope {
        imageRef.flipHorizontal;
    }

    ///
    void flipVertical() scope {
        imageRef.flipVertical;
    }

    ///
    void flipBoth() scope {
        imageRef.flipHorizontal;
        imageRef.flipVertical;
    }

    ///
    bool containsMetaData(Type)() scope {
        return imageRef.containsMetaData!Type;
    }

    ///
    void removeMetaData(Type)() scope {
        imageRef.removeMetaData!Type;
    }

    ///
    ImageMetaData!Type getMetaData(Type)() scope {
        return imageRef.getMetaData!Type;
    }

    ///
    size_t metaDataCount() scope {
        return imageRef.metaDataCount;
    }

    /// Seriously? this is not @safe and cannot be!!!
    CImage raw() scope @system {
        return imageRef.raw;
    }

    /// Ditto
    CImage raw(scope string channel) scope @system {
        CImage ret = imageRef.raw;
        size_t offsetSoFar;

        foreach (channelSpec; this.colorSpace.channels) {
            if (channelSpec.name == channel) {
                ret.dataBegin += offsetSoFar;
                ret.pixelChannelsSize = channelSpec.numberOfBytes;
                return ret;
            }

            offsetSoFar += channelSpec.numberOfBytes;
        }

        return CImage.init;
    }
}