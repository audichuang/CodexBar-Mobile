/// Fork-owned identity constants; values must match Scripts/apply_fork_identity.sh output; callers migrate later.
public enum ForkIdentity {
    public static let iCloudContainer = "iCloud.com.audichuang.codexbar"
    public static let appGroup = "group.com.audichuang.codexbar"
    public static let repoSlug = "audichuang/CodexBar-Mobile"
    public static let repoURL = "https://github.com/audichuang/CodexBar-Mobile"
    public static let helpURL = "https://github.com/audichuang/CodexBar-Mobile/blob/mobile-dev/README.md"
    public static let oslogSubsystem = "com.audichuang.codexbar"
    public static let widgetOslogSubsystem = oslogSubsystem + ".mobile.widgets"
    public static let providerZoneDidChangeNotification = oslogSubsystem + ".providerZoneDidChange"
}
