module sidero.image.defs;
import sidero.image.metadata.defs;
import sidero.colorimetry.colorspace;
import sidero.colorimetry.pixel;
import sidero.base.allocators;
import sidero.base.errors;
import sidero.base.attributes;

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
    package(sidero.image) @PrettyPrintIgnore {
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
    this(ColorSpace colorSpace, size_t width, size_t height, RCAllocator allocator = RCAllocator.init, size_t alignment = 4) scope @trusted {
        if (allocator.isNull)
            allocator = globalAllocator();

        imageRef = ImageRef(allocator.make!ImageState(allocator, colorSpace, cast(size_t[2])[width, height], alignment));
        this.colorSpace = colorSpace;
    }

    ///
    unittest {
        ColorSpace colorSpace = sRGB8();
        Image image = Image(colorSpace, 2, 2);
        assert(!image.isNull);
        assert(image.width == 2);
        assert(image.height == 2);

        static ubyte[3][4] Values = [[34, 72, 59], [44, 82, 69], [134, 172, 159], [144, 182, 169]];

        {
            auto pixel = image[0, 0];
            assert(pixel);
            auto got = pixel.set(Values[0][0], Values[0][1], Values[0][2]);
            assert(got);

            pixel = image[1, 0];
            assert(pixel);
            got = pixel.set(Values[1][0], Values[1][1], Values[1][2]);
            assert(got);

            pixel = image[0, 1];
            assert(pixel);
            got = pixel.set(Values[2][0], Values[2][1], Values[2][2]);
            assert(got);

            pixel = image[1, 1];
            assert(pixel);
            got = pixel.set(Values[3][0], Values[3][1], Values[3][2]);
            assert(got);
        }

        image.flipBoth;

        {
            static Offsets = [3, 2, 1, 0];
            size_t offset;

            foreach (y; 0 .. 2) {
                foreach (x; 0 .. 2) {
                    auto pixel = image[x, y];
                    assert(pixel);

                    auto r = pixel.channel!ubyte("r");
                    assert(r);
                    auto g = pixel.channel!ubyte("g");
                    assert(g);
                    auto b = pixel.channel!ubyte("b");
                    assert(b);

                    assert(r == Values[Offsets[offset]][0]);
                    assert(g == Values[Offsets[offset]][1]);
                    assert(b == Values[Offsets[offset]][2]);

                    offset++;
                }
            }
        }

        {
            Result!Image sliced = image[0 .. 1, 0 .. 1];
            assert(sliced);
            assert(sliced.width == 1);
            assert(sliced.height == 1);

            auto pixel = image[0, 0];
            assert(pixel);

            auto r = pixel.channel!ubyte("r");
            assert(r);
            auto g = pixel.channel!ubyte("g");
            assert(g);
            auto b = pixel.channel!ubyte("b");
            assert(b);

            assert(r == Values[3][0]);
            assert(g == Values[3][1]);
            assert(b == Values[3][2]);
        }

        {
            static struct SomeInfo {
                int number;
            }

            assert(image.metaDataCount == 0);
            assert(!image.containsMetaData!SomeInfo);

            auto got = image.getMetaData!SomeInfo;
            assert(image.metaDataCount == 1);
            got.number = 27;

            auto got2 = image.getMetaData!SomeInfo;
            assert(image.metaDataCount == 1);
            assert(got2.number == 27);

            image.removeMetaData!SomeInfo;
            assert(image.metaDataCount == 0);
        }
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
    size_t width() scope {
        if (isNull)
            return 0;
        return imageRef.width;
    }

    ///
    size_t height() scope {
        if (isNull)
            return 0;
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
    PixelReference opIndex(size_t x, size_t y) scope return @trusted {
        if (isNull)
            return typeof(return)(NullPointerException);

        assert(x < imageRef.width);
        assert(y < imageRef.height);

        void* location = imageRef.dataBegin + (imageRef.rowStride * y) + (imageRef.pixelStride * x);
        const size = imageRef.pixelStride < 0 ? -imageRef.pixelStride : imageRef.pixelStride;
        void[] array = location[0 .. size];

        imageRef.addRef;
        return typeof(return)(Pixel(array, this.colorSpace, cast(void*)null, &imageRef.rc));
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
