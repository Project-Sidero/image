module sidero.image.metadata.defs;
import sidero.image.defs;

///
struct ImageMetaData(Type) {
    private {
        import sidero.image.internal.state : MetaDataStorage, MetaDataStorageReference;

        MetaDataStorageReference reference;
        Image image;
    }

export @safe nothrow @nogc:

    ///
    this(MetaDataStorageReference reference, Image image) scope {
        cast(void)this.reference.opAssign(reference);
        this.image = image;
    }

    ///
    this(scope ref ImageMetaData other) scope {
        this.tupleof = other.tupleof;
    }

    @disable this(this);

    ///
    void opAssign(scope ref ImageMetaData other) scope {
        __ctor(other);
    }

    ///
    ref Type get() scope return @trusted {
        if (isNull)
            assert(0);

        Type* ret = reference.get.getMetaDataRef!Type();
        assert(ret !is null);

        return *ret;
    }

    ///
    alias get this;

    ///
    Image getImage() scope return {
        return image;
    }

    ///
    bool isNull() scope const {
        if (!reference || reference.isNull)
            return true;

        static if (__traits(hasMember, Type, "isNull")) {
            Type* ret = reference.getMetaDataRef!Type();
            assert(ret !is null);
            return ret.isNull;
        } else
            return false;
    }
}
