module sidero.image.metadata.defs;
import sidero.image.defs;

///
struct ImageMetaData(Type) {
    private {
        import image.internal.state : MetaDataStorage, MetaDataStorageReference;

        MetaDataStorageReference reference;
        Image image;
    }

export @safe nothrow @nogc:

    ///
    this(MetaDataStorageReference reference, Image image) scope {
        this.reference = reference;
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
    ref Type _get() scope {
        if (isNull)
            assert(0);

        Type* ret = reference.get.getMetaDataRef!Type();
        assert(ret !is null);

        return *ret;
    }

    ///
    alias _get this;

    ///
    Image getImage() scope {
        return image;
    }

    ///
    bool isNull() scope const {
        if (reference.isNull)
            return true;

        static if (__traits(hasMember, Type, "isNull")) {
            Type* ret = reference.getMetaDataRef!Type();
            assert(ret !is null);
            return ret.isNull;
        } else
            return false;
    }
}
