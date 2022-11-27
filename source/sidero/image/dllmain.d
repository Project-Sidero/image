module sidero.image.dllmain;
export:

version (DynamicSideroImage)  : version (Windows)  : version (D_BetterC) {
    import core.sys.windows.windef : HINSTANCE, BOOL, DWORD, LPVOID;

    extern (Windows) BOOL DllMain(HINSTANCE hInstance, DWORD ulReason, LPVOID reserved) {
        return true;
    }
} else {
    import core.sys.windows.dll;

    mixin SimpleDllMain;
}
