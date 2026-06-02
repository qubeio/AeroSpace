public let stableAeroSpaceAppId: String = "com.qubeio.aerospace"
#if DEBUG
    public let aeroSpaceAppId: String = "com.qubeio.aerospace.debug"
    public let aeroSpaceAppName: String = "AeroSpace-Debug"
#else
    public let aeroSpaceAppId: String = stableAeroSpaceAppId
    public let aeroSpaceAppName: String = "AeroSpace"
#endif
