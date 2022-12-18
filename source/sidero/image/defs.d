module sidero.image.defs;
import sidero.colorimetry.colorspace;
import sidero.colorimetry.pixel;

export:

struct CImage {
    void* dataBegin;
    size_t width, height, pixelChannelsSize;
    ptrdiff_t pixelPitch, rowStride;
}

struct Image {
    package(sidero.image) {
        import sidero.image.internal.state;

        ImageRef imageRef;
        ColorSpace colorSpace;
    }

export @safe nothrow @nogc:

}
