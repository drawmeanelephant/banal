import BANALScripting

/// Wires the AppleScript surface into the app at launch. The sdef's
/// `<cocoa class>` entries dispatch to the command classes; keeping a symbol
/// reference alive here stops release builds dead-stripping them.
enum ScriptingBootstrap {
    static func register() {
        ScriptingEventHandlers.keepAlive()
    }
}
