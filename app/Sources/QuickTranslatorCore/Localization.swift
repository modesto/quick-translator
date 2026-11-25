import Foundation

public enum UILanguage: String, CaseIterable, Sendable {
    case es, en, fr, de, it, pt

    public static func forLanguage(_ code: String) -> UILanguage {
        UILanguage(rawValue: code) ?? .en
    }

    public var locale: Locale { Locale(identifier: rawValue) }

    public var strings: UIStrings {
        switch self {
        case .es: return .es
        case .en: return .en
        case .fr: return .fr
        case .de: return .de
        case .it: return .it
        case .pt: return .pt
        }
    }
}

public enum L10n {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var current: UILanguage = .es

    public static var language: UILanguage {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    public static var strings: UIStrings { language.strings }
}

public struct UIStrings: Sendable {
    public typealias Format = @Sendable (String) -> String
    public typealias Format2 = @Sendable (String, String) -> String

    public let translateSelection: String
    public let settingsEllipsis: String
    public let accessibilityPermission: String
    public let quit: String
    public let quitApp: String
    public let editMenu: String
    public let undo: String
    public let redo: String
    public let cut: String
    public let copy: String
    public let paste: String
    public let selectAll: String
    public let noSelectedText: String

    public let openSettings: String
    public let notNow: String
    public let ok: String
    public let languageMissingTitle: String
    public let languageMissingMessage: Format2
    public let pairUnsupportedTitle: String
    public let pairUnsupportedMessage: Format2

    public let close: String
    public let onDevice: String
    public let downloadLanguage: String
    public let downloadLanguageHelp: String
    public let translateWith: Format
    public let retry: String
    public let responseTime: String
    public let configuredLanguages: String
    public let translatingOnceTo: Format
    public let translateOnceHelp: String
    public let requestVariantsHelp: String
    public let translating: String
    public let use: Format
    public let useHelp: Format

    public let settingsTitle: String
    public let generalTab: String
    public let providerTab: String
    public let shortcutSection: String
    public let myLanguage: String
    public let targetLanguage: String
    public let languagesSection: String
    public let languagesFooter: String
    public let startupSection: String
    public let launchAtLogin: String
    public let launchAtLoginApproval: String
    public let openLoginItems: String
    public let launchAtLoginFailed: Format
    public let provider: String
    public let translateAutomatically: String
    public let variantsSection: String
    public let automaticFooter: Format
    public let manualFooter: Format
    public let test: String
    public let claudeCodeDetails: String
    public let billedSeparately: String
    public let billedByUsage: String
    public let keyOptional: String
    public let deepLHelp: String
    public let model: String
    public let apiURL: String
    public let save: String
    public let remove: String
    public let officialURLHelp: String
    public let compatibleURLHelp: String
    public let invalidURL: String
    public let modelPlaceholder: String
    public let openAIModelsHelp: String
    public let keySaved: String
    public let createKeyAt: Format
    public let getDeepLKey: String
    public let testSentence: String
    public let fastest: String
    public let fastestCheapest: String
    public let moreQuality: String
    public let bestQuality: String

    public let pressNewShortcut: String
    public let shortcutChanged: Format
    public let recordShortcut: String
    public let cancel: String
    public let reset: String
    public let resetHelp: Format
    public let spaceKey: String
    public let shortcutUnavailable: Format
    public let shortcutNeedsModifier: String
    public let shortcutReserved: Format

    public let cliNotFound: String
    public let serverStopped: String
    public let translationFailed: String
    public let unknownLanguage: String
    public let alreadyIn: Format
    public let notInstalled: Format2
    public let missingKey: Format
    public let authFailed: Format
    public let quotaExceeded: Format
    public let rateLimited: Format
    public let unsupportedLanguage: Format
    public let refused: Format
    public let network: Format
    public let providerFailed: Format2
}

extension UIStrings {
    public static let es = UIStrings(
        translateSelection: "Traducir selección",
        settingsEllipsis: "Ajustes…",
        accessibilityPermission: "Permiso de Accesibilidad…",
        quit: "Salir",
        quitApp: "Salir de Quick Translator",
        editMenu: "Edición",
        undo: "Deshacer",
        redo: "Rehacer",
        cut: "Cortar",
        copy: "Copiar",
        paste: "Pegar",
        selectAll: "Seleccionar todo",
        noSelectedText: "No hay texto seleccionado",
        openSettings: "Abrir Ajustes",
        notNow: "Ahora no",
        ok: "Aceptar",
        languageMissingTitle: "Falta descargar un idioma",
        languageMissingMessage: { "Apple Translation necesita los idiomas \($0) y \($1) descargados en el Mac. Hasta entonces solo traducirá el otro proveedor.\n\nEn Idioma y región, pulsa «Idiomas de traducción…» y descarga los que falten." },
        pairUnsupportedTitle: "Apple Translation no admite este par",
        pairUnsupportedMessage: { "Apple Translation no traduce entre \($0) y \($1). Para este par solo traducirá el otro proveedor." },
        close: "Cerrar (Esc)",
        onDevice: "En el Mac",
        downloadLanguage: "Descargar idioma…",
        downloadLanguageHelp: "Abre Idioma y región; pulsa «Idiomas de traducción…» para descargarlo",
        translateWith: { "Traducir con \($0)" },
        retry: "Reintentar",
        responseTime: "Tiempo de respuesta",
        configuredLanguages: "Idiomas configurados",
        translatingOnceTo: { "Traduciendo a \($0) solo esta vez" },
        translateOnceHelp: "Traducir a otro idioma solo esta vez",
        requestVariantsHelp: "Pedir las versiones (tecla C)",
        translating: "Traduciendo…",
        use: { "Usar \($0)" },
        useHelp: { "Sustituir la selección (tecla \($0))" },
        settingsTitle: "Ajustes de Quick Translator",
        generalTab: "General",
        providerTab: "Proveedor",
        shortcutSection: "Atajo de teclado",
        myLanguage: "Mi idioma",
        targetLanguage: "Idioma destino",
        languagesSection: "Idiomas",
        languagesFooter: "Lo que esté en tu idioma se traduce al destino; cualquier otro idioma, al tuyo. La app se muestra en tu idioma.",
        startupSection: "Inicio",
        launchAtLogin: "Abrir al iniciar sesión",
        launchAtLoginApproval: "Falta permitirlo en Ajustes del Sistema → General → Ítems de inicio.",
        openLoginItems: "Abrir Ítems de inicio…",
        launchAtLoginFailed: { "No se ha podido cambiar: \($0)" },
        provider: "Proveedor",
        translateAutomatically: "Traducir automáticamente",
        variantsSection: "Varias versiones",
        automaticFooter: { "Se pide a \($0) en cada traducción, junto a Apple Translation." },
        manualFooter: { "El pop-up muestra un botón para pedir las versiones a \($0) (tecla C)." },
        test: "Probar",
        claudeCodeDetails: "Usa tu sesión de Claude Code; no necesita clave. Modelo: Claude Haiku 5.5.",
        billedSeparately: "Se factura aparte de tu suscripción.",
        billedByUsage: "Se factura aparte, según el uso.",
        keyOptional: "Opcional si tu servidor no pide clave.",
        deepLHelp: "Las claves gratuitas terminan en :fx. Da una versión formal y otra informal cuando el idioma lo admite.",
        model: "Modelo",
        apiURL: "URL del API",
        save: "Guardar",
        remove: "Borrar",
        officialURLHelp: "Vacía, se usa la de OpenAI. Cámbiala para usar un servidor compatible (Ollama, OpenRouter, Groq…).",
        compatibleURLHelp: "Servidor compatible: se usa su API Chat Completions. Vacía, vuelve a la de OpenAI.",
        invalidURL: "La URL no es válida. Debe empezar por http:// o https://.",
        modelPlaceholder: "Nombre del modelo, p. ej. llama3.2",
        openAIModelsHelp: "Modelos de OpenAI",
        keySaved: "Clave guardada en el Llavero",
        createKeyAt: { "Crear una clave en \($0)" },
        getDeepLKey: "Conseguir una clave de DeepL API (hay plan gratuito)",
        testSentence: "Hola, ¿nos vemos mañana a primera hora?",
        fastest: "la más rápida",
        fastestCheapest: "la más rápida y barata",
        moreQuality: "más calidad",
        bestQuality: "la de más calidad, más lenta",
        pressNewShortcut: "Pulsa la nueva combinación. Esc para cancelar.",
        shortcutChanged: { "Atajo cambiado a \($0)." },
        recordShortcut: "Grabar nuevo atajo",
        cancel: "Cancelar",
        reset: "Restablecer",
        resetHelp: { "Volver a \($0)" },
        spaceKey: "Espacio",
        shortcutUnavailable: { "\($0) no está disponible: lo usa otra app o el sistema." },
        shortcutNeedsModifier: "El atajo necesita al menos ⌘, ⌥ o ⌃.",
        shortcutReserved: { "\($0) es un atajo del sistema o de edición. Elige otro." },
        cliNotFound: "No se encuentra el CLI quick-translate (QTNodePath / QTCLIPath en Info.plist).",
        serverStopped: "El proceso de traducción se ha detenido. Vuelve a intentarlo.",
        translationFailed: "La traducción falló.",
        unknownLanguage: "No se ha podido detectar el idioma.",
        alreadyIn: { "El texto ya está en \($0)." },
        notInstalled: { "Falta descargar \($0) → \($1) para traducir en el Mac." },
        missingKey: { "Falta la clave de \($0). Añádela en Ajustes." },
        authFailed: { "\($0) ha rechazado la clave. Revísala en Ajustes." },
        quotaExceeded: { "Se ha agotado la cuota de \($0)." },
        rateLimited: { "Demasiadas peticiones a \($0). Espera un momento." },
        unsupportedLanguage: { "\($0) no admite este idioma." },
        refused: { "\($0) no ha querido traducir este texto." },
        network: { "No se ha podido conectar con \($0)." },
        providerFailed: { "\($0) ha fallado: \($1)" }
    )

    public static let en = UIStrings(
        translateSelection: "Translate Selection",
        settingsEllipsis: "Settings…",
        accessibilityPermission: "Accessibility Permission…",
        quit: "Quit",
        quitApp: "Quit Quick Translator",
        editMenu: "Edit",
        undo: "Undo",
        redo: "Redo",
        cut: "Cut",
        copy: "Copy",
        paste: "Paste",
        selectAll: "Select All",
        noSelectedText: "No text is selected",
        openSettings: "Open Settings",
        notNow: "Not Now",
        ok: "OK",
        languageMissingTitle: "A language needs to be downloaded",
        languageMissingMessage: { "Apple Translation needs \($0) and \($1) downloaded on this Mac. Until then only the other provider will translate.\n\nIn Language & Region, click “Translation Languages…” and download the missing ones." },
        pairUnsupportedTitle: "Apple Translation doesn’t support this pair",
        pairUnsupportedMessage: { "Apple Translation can’t translate between \($0) and \($1). For this pair only the other provider will translate." },
        close: "Close (Esc)",
        onDevice: "On this Mac",
        downloadLanguage: "Download Language…",
        downloadLanguageHelp: "Opens Language & Region; click “Translation Languages…” to download it",
        translateWith: { "Translate with \($0)" },
        retry: "Try Again",
        responseTime: "Response time",
        configuredLanguages: "Configured languages",
        translatingOnceTo: { "Translating into \($0) just this once" },
        translateOnceHelp: "Translate into another language just this once",
        requestVariantsHelp: "Get the versions (C key)",
        translating: "Translating…",
        use: { "Use \($0)" },
        useHelp: { "Replace the selection (\($0) key)" },
        settingsTitle: "Quick Translator Settings",
        generalTab: "General",
        providerTab: "Provider",
        shortcutSection: "Keyboard Shortcut",
        myLanguage: "My language",
        targetLanguage: "Target language",
        languagesSection: "Languages",
        languagesFooter: "Text in your language is translated into the target; text in any other language, into yours. The app is shown in your language.",
        startupSection: "Startup",
        launchAtLogin: "Open at login",
        launchAtLoginApproval: "Still needs your approval in System Settings → General → Login Items.",
        openLoginItems: "Open Login Items…",
        launchAtLoginFailed: { "Couldn’t change it: \($0)" },
        provider: "Provider",
        translateAutomatically: "Translate automatically",
        variantsSection: "Several versions",
        automaticFooter: { "\($0) is asked with every translation, next to Apple Translation." },
        manualFooter: { "The popup shows a button to get the versions from \($0) (C key)." },
        test: "Test",
        claudeCodeDetails: "Uses your Claude Code login; no key needed. Model: Claude Haiku 5.5.",
        billedSeparately: "Billed separately from your subscription.",
        billedByUsage: "Billed separately, by usage.",
        keyOptional: "Optional if your server doesn’t ask for a key.",
        deepLHelp: "Free keys end in :fx. Gives a formal and an informal version when the language supports it.",
        model: "Model",
        apiURL: "API URL",
        save: "Save",
        remove: "Delete",
        officialURLHelp: "Empty means OpenAI. Change it to use a compatible server (Ollama, OpenRouter, Groq…).",
        compatibleURLHelp: "Compatible server: its Chat Completions API is used. Empty goes back to OpenAI.",
        invalidURL: "The URL isn’t valid. It must start with http:// or https://.",
        modelPlaceholder: "Model name, e.g. llama3.2",
        openAIModelsHelp: "OpenAI models",
        keySaved: "Key saved in the Keychain",
        createKeyAt: { "Create a key at \($0)" },
        getDeepLKey: "Get a DeepL API key (there’s a free plan)",
        testSentence: "Hi, shall we meet first thing tomorrow?",
        fastest: "fastest",
        fastestCheapest: "fastest and cheapest",
        moreQuality: "higher quality",
        bestQuality: "highest quality, slower",
        pressNewShortcut: "Press the new combination. Esc to cancel.",
        shortcutChanged: { "Shortcut changed to \($0)." },
        recordShortcut: "Record New Shortcut",
        cancel: "Cancel",
        reset: "Reset",
        resetHelp: { "Go back to \($0)" },
        spaceKey: "Space",
        shortcutUnavailable: { "\($0) isn’t available: another app or the system uses it." },
        shortcutNeedsModifier: "The shortcut needs at least ⌘, ⌥ or ⌃.",
        shortcutReserved: { "\($0) is a system or editing shortcut. Choose another one." },
        cliNotFound: "The quick-translate CLI wasn’t found (QTNodePath / QTCLIPath in Info.plist).",
        serverStopped: "The translation process stopped. Try again.",
        translationFailed: "The translation failed.",
        unknownLanguage: "The language couldn’t be detected.",
        alreadyIn: { "The text is already in \($0)." },
        notInstalled: { "Download \($0) → \($1) to translate on this Mac." },
        missingKey: { "The \($0) key is missing. Add it in Settings." },
        authFailed: { "\($0) rejected the key. Check it in Settings." },
        quotaExceeded: { "The \($0) quota is used up." },
        rateLimited: { "Too many requests to \($0). Wait a moment." },
        unsupportedLanguage: { "\($0) doesn’t support this language." },
        refused: { "\($0) declined to translate this text." },
        network: { "Couldn’t connect to \($0)." },
        providerFailed: { "\($0) failed: \($1)" }
    )

    public static let fr = UIStrings(
        translateSelection: "Traduire la sélection",
        settingsEllipsis: "Réglages…",
        accessibilityPermission: "Autorisation d’accessibilité…",
        quit: "Quitter",
        quitApp: "Quitter Quick Translator",
        editMenu: "Édition",
        undo: "Annuler",
        redo: "Rétablir",
        cut: "Couper",
        copy: "Copier",
        paste: "Coller",
        selectAll: "Tout sélectionner",
        noSelectedText: "Aucun texte sélectionné",
        openSettings: "Ouvrir les réglages",
        notNow: "Plus tard",
        ok: "OK",
        languageMissingTitle: "Une langue doit être téléchargée",
        languageMissingMessage: { "Apple Translation a besoin que \($0) et \($1) soient téléchargés sur ce Mac. D’ici là, seul l’autre fournisseur traduira.\n\nDans Langue et région, cliquez sur « Langues de traduction… » et téléchargez celles qui manquent." },
        pairUnsupportedTitle: "Apple Translation ne prend pas en charge cette paire",
        pairUnsupportedMessage: { "Apple Translation ne traduit pas entre \($0) et \($1). Pour cette paire, seul l’autre fournisseur traduira." },
        close: "Fermer (Échap)",
        onDevice: "Sur ce Mac",
        downloadLanguage: "Télécharger la langue…",
        downloadLanguageHelp: "Ouvre Langue et région ; cliquez sur « Langues de traduction… » pour la télécharger",
        translateWith: { "Traduire avec \($0)" },
        retry: "Réessayer",
        responseTime: "Temps de réponse",
        configuredLanguages: "Langues configurées",
        translatingOnceTo: { "Traduction en \($0) pour cette fois seulement" },
        translateOnceHelp: "Traduire dans une autre langue pour cette fois seulement",
        requestVariantsHelp: "Obtenir les versions (touche C)",
        translating: "Traduction…",
        use: { "Utiliser \($0)" },
        useHelp: { "Remplacer la sélection (touche \($0))" },
        settingsTitle: "Réglages de Quick Translator",
        generalTab: "Général",
        providerTab: "Fournisseur",
        shortcutSection: "Raccourci clavier",
        myLanguage: "Ma langue",
        targetLanguage: "Langue cible",
        languagesSection: "Langues",
        languagesFooter: "Le texte dans votre langue est traduit dans la langue cible ; tout autre texte, dans la vôtre. L’app s’affiche dans votre langue.",
        startupSection: "Démarrage",
        launchAtLogin: "Ouvrir à l’ouverture de session",
        launchAtLoginApproval: "Doit encore être autorisé dans Réglages Système → Général → Ouverture.",
        openLoginItems: "Ouvrir les éléments d’ouverture…",
        launchAtLoginFailed: { "Impossible de le modifier : \($0)" },
        provider: "Fournisseur",
        translateAutomatically: "Traduire automatiquement",
        variantsSection: "Plusieurs versions",
        automaticFooter: { "\($0) est sollicité à chaque traduction, en plus d’Apple Translation." },
        manualFooter: { "La fenêtre affiche un bouton pour demander les versions à \($0) (touche C)." },
        test: "Tester",
        claudeCodeDetails: "Utilise votre session Claude Code ; aucune clé nécessaire. Modèle : Claude Haiku 5.5.",
        billedSeparately: "Facturé séparément de votre abonnement.",
        billedByUsage: "Facturé séparément, selon l’usage.",
        keyOptional: "Facultative si votre serveur ne demande pas de clé.",
        deepLHelp: "Les clés gratuites se terminent par :fx. Donne une version formelle et une informelle quand la langue le permet.",
        model: "Modèle",
        apiURL: "URL de l’API",
        save: "Enregistrer",
        remove: "Supprimer",
        officialURLHelp: "Vide, c’est celle d’OpenAI. Modifiez-la pour utiliser un serveur compatible (Ollama, OpenRouter, Groq…).",
        compatibleURLHelp: "Serveur compatible : son API Chat Completions est utilisée. Vide, on revient à OpenAI.",
        invalidURL: "L’URL n’est pas valide. Elle doit commencer par http:// ou https://.",
        modelPlaceholder: "Nom du modèle, p. ex. llama3.2",
        openAIModelsHelp: "Modèles OpenAI",
        keySaved: "Clé enregistrée dans le trousseau",
        createKeyAt: { "Créer une clé sur \($0)" },
        getDeepLKey: "Obtenir une clé API DeepL (offre gratuite disponible)",
        testSentence: "Bonjour, on se voit demain à la première heure ?",
        fastest: "le plus rapide",
        fastestCheapest: "le plus rapide et le moins cher",
        moreQuality: "meilleure qualité",
        bestQuality: "la meilleure qualité, plus lent",
        pressNewShortcut: "Appuyez sur la nouvelle combinaison. Échap pour annuler.",
        shortcutChanged: { "Raccourci remplacé par \($0)." },
        recordShortcut: "Enregistrer un raccourci",
        cancel: "Annuler",
        reset: "Réinitialiser",
        resetHelp: { "Revenir à \($0)" },
        spaceKey: "Espace",
        shortcutUnavailable: { "\($0) n’est pas disponible : une autre app ou le système l’utilise." },
        shortcutNeedsModifier: "Le raccourci doit contenir au moins ⌘, ⌥ ou ⌃.",
        shortcutReserved: { "\($0) est un raccourci du système ou d’édition. Choisissez-en un autre." },
        cliNotFound: "Le CLI quick-translate est introuvable (QTNodePath / QTCLIPath dans Info.plist).",
        serverStopped: "Le processus de traduction s’est arrêté. Réessayez.",
        translationFailed: "La traduction a échoué.",
        unknownLanguage: "Impossible de détecter la langue.",
        alreadyIn: { "Le texte est déjà en \($0)." },
        notInstalled: { "Téléchargez \($0) → \($1) pour traduire sur ce Mac." },
        missingKey: { "La clé \($0) manque. Ajoutez-la dans les réglages." },
        authFailed: { "\($0) a refusé la clé. Vérifiez-la dans les réglages." },
        quotaExceeded: { "Le quota de \($0) est épuisé." },
        rateLimited: { "Trop de requêtes vers \($0). Patientez un instant." },
        unsupportedLanguage: { "\($0) ne prend pas en charge cette langue." },
        refused: { "\($0) a refusé de traduire ce texte." },
        network: { "Impossible de se connecter à \($0)." },
        providerFailed: { "\($0) a échoué : \($1)" }
    )

    public static let de = UIStrings(
        translateSelection: "Auswahl übersetzen",
        settingsEllipsis: "Einstellungen …",
        accessibilityPermission: "Bedienungshilfen-Berechtigung …",
        quit: "Beenden",
        quitApp: "Quick Translator beenden",
        editMenu: "Bearbeiten",
        undo: "Widerrufen",
        redo: "Wiederholen",
        cut: "Ausschneiden",
        copy: "Kopieren",
        paste: "Einsetzen",
        selectAll: "Alles auswählen",
        noSelectedText: "Kein Text ausgewählt",
        openSettings: "Einstellungen öffnen",
        notNow: "Nicht jetzt",
        ok: "OK",
        languageMissingTitle: "Eine Sprache muss geladen werden",
        languageMissingMessage: { "Apple Translation braucht \($0) und \($1) auf diesem Mac. Bis dahin übersetzt nur der andere Anbieter.\n\nKlicke unter Sprache & Region auf „Übersetzungssprachen …“ und lade die fehlenden Sprachen." },
        pairUnsupportedTitle: "Apple Translation unterstützt dieses Paar nicht",
        pairUnsupportedMessage: { "Apple Translation übersetzt nicht zwischen \($0) und \($1). Für dieses Paar übersetzt nur der andere Anbieter." },
        close: "Schließen (Esc)",
        onDevice: "Auf diesem Mac",
        downloadLanguage: "Sprache laden …",
        downloadLanguageHelp: "Öffnet Sprache & Region; klicke auf „Übersetzungssprachen …“, um sie zu laden",
        translateWith: { "Mit \($0) übersetzen" },
        retry: "Erneut versuchen",
        responseTime: "Antwortzeit",
        configuredLanguages: "Eingestellte Sprachen",
        translatingOnceTo: { "Nur dieses Mal übersetzen in: \($0)" },
        translateOnceHelp: "Nur dieses Mal in eine andere Sprache übersetzen",
        requestVariantsHelp: "Versionen anfordern (Taste C)",
        translating: "Übersetzen …",
        use: { "\($0) verwenden" },
        useHelp: { "Auswahl ersetzen (Taste \($0))" },
        settingsTitle: "Quick Translator – Einstellungen",
        generalTab: "Allgemein",
        providerTab: "Anbieter",
        shortcutSection: "Tastenkurzbefehl",
        myLanguage: "Meine Sprache",
        targetLanguage: "Zielsprache",
        languagesSection: "Sprachen",
        languagesFooter: "Text in deiner Sprache wird in die Zielsprache übersetzt, Text in jeder anderen Sprache in deine. Die App wird in deiner Sprache angezeigt.",
        startupSection: "Start",
        launchAtLogin: "Beim Anmelden öffnen",
        launchAtLoginApproval: "Muss noch in Systemeinstellungen → Allgemein → Anmeldeobjekte erlaubt werden.",
        openLoginItems: "Anmeldeobjekte öffnen …",
        launchAtLoginFailed: { "Konnte nicht geändert werden: \($0)" },
        provider: "Anbieter",
        translateAutomatically: "Automatisch übersetzen",
        variantsSection: "Mehrere Versionen",
        automaticFooter: { "\($0) wird bei jeder Übersetzung gefragt, zusätzlich zu Apple Translation." },
        manualFooter: { "Das Pop-up zeigt eine Taste, um die Versionen bei \($0) anzufordern (Taste C)." },
        test: "Testen",
        claudeCodeDetails: "Nutzt deine Claude-Code-Anmeldung; kein Schlüssel nötig. Modell: Claude Haiku 5.5.",
        billedSeparately: "Wird getrennt von deinem Abo abgerechnet.",
        billedByUsage: "Wird getrennt nach Nutzung abgerechnet.",
        keyOptional: "Optional, wenn dein Server keinen Schlüssel verlangt.",
        deepLHelp: "Kostenlose Schlüssel enden auf :fx. Liefert eine formelle und eine informelle Version, wenn die Sprache das unterstützt.",
        model: "Modell",
        apiURL: "API-URL",
        save: "Sichern",
        remove: "Löschen",
        officialURLHelp: "Leer bedeutet OpenAI. Ändere sie, um einen kompatiblen Server zu nutzen (Ollama, OpenRouter, Groq …).",
        compatibleURLHelp: "Kompatibler Server: Seine Chat-Completions-API wird genutzt. Leer führt zurück zu OpenAI.",
        invalidURL: "Die URL ist ungültig. Sie muss mit http:// oder https:// beginnen.",
        modelPlaceholder: "Modellname, z. B. llama3.2",
        openAIModelsHelp: "OpenAI-Modelle",
        keySaved: "Schlüssel im Schlüsselbund gesichert",
        createKeyAt: { "Schlüssel auf \($0) erstellen" },
        getDeepLKey: "DeepL-API-Schlüssel holen (es gibt einen kostenlosen Tarif)",
        testSentence: "Hallo, sehen wir uns morgen gleich als Erstes?",
        fastest: "am schnellsten",
        fastestCheapest: "am schnellsten und günstigsten",
        moreQuality: "höhere Qualität",
        bestQuality: "höchste Qualität, langsamer",
        pressNewShortcut: "Drücke die neue Kombination. Esc zum Abbrechen.",
        shortcutChanged: { "Kurzbefehl geändert in \($0)." },
        recordShortcut: "Neuen Kurzbefehl aufnehmen",
        cancel: "Abbrechen",
        reset: "Zurücksetzen",
        resetHelp: { "Zurück zu \($0)" },
        spaceKey: "Leertaste",
        shortcutUnavailable: { "\($0) ist nicht verfügbar: Eine andere App oder das System nutzt ihn." },
        shortcutNeedsModifier: "Der Kurzbefehl braucht mindestens ⌘, ⌥ oder ⌃.",
        shortcutReserved: { "\($0) ist ein System- oder Bearbeitungskurzbefehl. Wähle einen anderen." },
        cliNotFound: "Das CLI quick-translate wurde nicht gefunden (QTNodePath / QTCLIPath in Info.plist).",
        serverStopped: "Der Übersetzungsprozess wurde beendet. Versuche es erneut.",
        translationFailed: "Die Übersetzung ist fehlgeschlagen.",
        unknownLanguage: "Die Sprache konnte nicht erkannt werden.",
        alreadyIn: { "Der Text ist bereits auf \($0)." },
        notInstalled: { "Lade \($0) → \($1), um auf diesem Mac zu übersetzen." },
        missingKey: { "Der Schlüssel für \($0) fehlt. Füge ihn in den Einstellungen hinzu." },
        authFailed: { "\($0) hat den Schlüssel abgelehnt. Prüfe ihn in den Einstellungen." },
        quotaExceeded: { "Das Kontingent von \($0) ist aufgebraucht." },
        rateLimited: { "Zu viele Anfragen an \($0). Warte einen Moment." },
        unsupportedLanguage: { "\($0) unterstützt diese Sprache nicht." },
        refused: { "\($0) hat die Übersetzung dieses Texts abgelehnt." },
        network: { "Keine Verbindung zu \($0)." },
        providerFailed: { "\($0) ist fehlgeschlagen: \($1)" }
    )

    public static let it = UIStrings(
        translateSelection: "Traduci selezione",
        settingsEllipsis: "Impostazioni…",
        accessibilityPermission: "Permesso di accessibilità…",
        quit: "Esci",
        quitApp: "Esci da Quick Translator",
        editMenu: "Modifica",
        undo: "Annulla",
        redo: "Ripristina",
        cut: "Taglia",
        copy: "Copia",
        paste: "Incolla",
        selectAll: "Seleziona tutto",
        noSelectedText: "Nessun testo selezionato",
        openSettings: "Apri Impostazioni",
        notNow: "Non ora",
        ok: "OK",
        languageMissingTitle: "Devi scaricare una lingua",
        languageMissingMessage: { "Apple Translation ha bisogno di \($0) e \($1) scaricati su questo Mac. Fino ad allora tradurrà solo l’altro fornitore.\n\nIn Lingua e zona, fai clic su «Lingue di traduzione…» e scarica quelle mancanti." },
        pairUnsupportedTitle: "Apple Translation non supporta questa coppia",
        pairUnsupportedMessage: { "Apple Translation non traduce tra \($0) e \($1). Per questa coppia tradurrà solo l’altro fornitore." },
        close: "Chiudi (Esc)",
        onDevice: "Su questo Mac",
        downloadLanguage: "Scarica lingua…",
        downloadLanguageHelp: "Apre Lingua e zona; fai clic su «Lingue di traduzione…» per scaricarla",
        translateWith: { "Traduci con \($0)" },
        retry: "Riprova",
        responseTime: "Tempo di risposta",
        configuredLanguages: "Lingue configurate",
        translatingOnceTo: { "Traduzione in \($0) solo questa volta" },
        translateOnceHelp: "Traduci in un’altra lingua solo questa volta",
        requestVariantsHelp: "Chiedi le versioni (tasto C)",
        translating: "Traduzione…",
        use: { "Usa \($0)" },
        useHelp: { "Sostituisci la selezione (tasto \($0))" },
        settingsTitle: "Impostazioni di Quick Translator",
        generalTab: "Generali",
        providerTab: "Fornitore",
        shortcutSection: "Abbreviazione da tastiera",
        myLanguage: "La mia lingua",
        targetLanguage: "Lingua di destinazione",
        languagesSection: "Lingue",
        languagesFooter: "Il testo nella tua lingua viene tradotto nella lingua di destinazione; qualsiasi altra lingua, nella tua. L’app viene mostrata nella tua lingua.",
        startupSection: "Avvio",
        launchAtLogin: "Apri al login",
        launchAtLoginApproval: "Va ancora consentito in Impostazioni di Sistema → Generali → Elementi login.",
        openLoginItems: "Apri Elementi login…",
        launchAtLoginFailed: { "Impossibile modificarlo: \($0)" },
        provider: "Fornitore",
        translateAutomatically: "Traduci automaticamente",
        variantsSection: "Più versioni",
        automaticFooter: { "\($0) viene interpellato a ogni traduzione, insieme ad Apple Translation." },
        manualFooter: { "Il pop-up mostra un pulsante per chiedere le versioni a \($0) (tasto C)." },
        test: "Prova",
        claudeCodeDetails: "Usa il tuo accesso a Claude Code; non serve una chiave. Modello: Claude Haiku 5.5.",
        billedSeparately: "Fatturato separatamente dal tuo abbonamento.",
        billedByUsage: "Fatturato separatamente, in base all’uso.",
        keyOptional: "Facoltativa se il tuo server non richiede una chiave.",
        deepLHelp: "Le chiavi gratuite terminano con :fx. Fornisce una versione formale e una informale quando la lingua lo consente.",
        model: "Modello",
        apiURL: "URL dell’API",
        save: "Salva",
        remove: "Elimina",
        officialURLHelp: "Vuota, si usa quella di OpenAI. Cambiala per usare un server compatibile (Ollama, OpenRouter, Groq…).",
        compatibleURLHelp: "Server compatibile: si usa la sua API Chat Completions. Vuota, si torna a OpenAI.",
        invalidURL: "L’URL non è valido. Deve iniziare con http:// o https://.",
        modelPlaceholder: "Nome del modello, ad es. llama3.2",
        openAIModelsHelp: "Modelli OpenAI",
        keySaved: "Chiave salvata nel portachiavi",
        createKeyAt: { "Crea una chiave su \($0)" },
        getDeepLKey: "Ottieni una chiave API DeepL (c’è un piano gratuito)",
        testSentence: "Ciao, ci vediamo domani a prima ora?",
        fastest: "il più veloce",
        fastestCheapest: "il più veloce ed economico",
        moreQuality: "qualità superiore",
        bestQuality: "la qualità migliore, più lento",
        pressNewShortcut: "Premi la nuova combinazione. Esc per annullare.",
        shortcutChanged: { "Abbreviazione cambiata in \($0)." },
        recordShortcut: "Registra nuova abbreviazione",
        cancel: "Annulla",
        reset: "Ripristina",
        resetHelp: { "Torna a \($0)" },
        spaceKey: "Spazio",
        shortcutUnavailable: { "\($0) non è disponibile: lo usa un’altra app o il sistema." },
        shortcutNeedsModifier: "L’abbreviazione richiede almeno ⌘, ⌥ o ⌃.",
        shortcutReserved: { "\($0) è un’abbreviazione di sistema o di modifica. Scegline un’altra." },
        cliNotFound: "CLI quick-translate non trovato (QTNodePath / QTCLIPath in Info.plist).",
        serverStopped: "Il processo di traduzione si è fermato. Riprova.",
        translationFailed: "La traduzione non è riuscita.",
        unknownLanguage: "Impossibile rilevare la lingua.",
        alreadyIn: { "Il testo è già in \($0)." },
        notInstalled: { "Scarica \($0) → \($1) per tradurre su questo Mac." },
        missingKey: { "Manca la chiave di \($0). Aggiungila nelle impostazioni." },
        authFailed: { "\($0) ha rifiutato la chiave. Controllala nelle impostazioni." },
        quotaExceeded: { "La quota di \($0) è esaurita." },
        rateLimited: { "Troppe richieste a \($0). Attendi un momento." },
        unsupportedLanguage: { "\($0) non supporta questa lingua." },
        refused: { "\($0) si è rifiutato di tradurre questo testo." },
        network: { "Impossibile connettersi a \($0)." },
        providerFailed: { "\($0) non è riuscito: \($1)" }
    )

    public static let pt = UIStrings(
        translateSelection: "Traduzir seleção",
        settingsEllipsis: "Definições…",
        accessibilityPermission: "Permissão de acessibilidade…",
        quit: "Sair",
        quitApp: "Sair do Quick Translator",
        editMenu: "Edição",
        undo: "Desfazer",
        redo: "Refazer",
        cut: "Cortar",
        copy: "Copiar",
        paste: "Colar",
        selectAll: "Selecionar tudo",
        noSelectedText: "Não há texto selecionado",
        openSettings: "Abrir definições",
        notNow: "Agora não",
        ok: "OK",
        languageMissingTitle: "Falta descarregar um idioma",
        languageMissingMessage: { "O Apple Translation precisa de \($0) e \($1) descarregados neste Mac. Até lá, só o outro fornecedor vai traduzir.\n\nEm Idioma e região, clique em “Idiomas de tradução…” e descarregue os que faltam." },
        pairUnsupportedTitle: "O Apple Translation não suporta este par",
        pairUnsupportedMessage: { "O Apple Translation não traduz entre \($0) e \($1). Para este par, só o outro fornecedor vai traduzir." },
        close: "Fechar (Esc)",
        onDevice: "Neste Mac",
        downloadLanguage: "Descarregar idioma…",
        downloadLanguageHelp: "Abre Idioma e região; clique em “Idiomas de tradução…” para o descarregar",
        translateWith: { "Traduzir com \($0)" },
        retry: "Tentar novamente",
        responseTime: "Tempo de resposta",
        configuredLanguages: "Idiomas configurados",
        translatingOnceTo: { "A traduzir para \($0) só desta vez" },
        translateOnceHelp: "Traduzir para outro idioma só desta vez",
        requestVariantsHelp: "Pedir as versões (tecla C)",
        translating: "A traduzir…",
        use: { "Usar \($0)" },
        useHelp: { "Substituir a seleção (tecla \($0))" },
        settingsTitle: "Definições do Quick Translator",
        generalTab: "Geral",
        providerTab: "Fornecedor",
        shortcutSection: "Atalho de teclado",
        myLanguage: "O meu idioma",
        targetLanguage: "Idioma de destino",
        languagesSection: "Idiomas",
        languagesFooter: "O texto no seu idioma é traduzido para o destino; qualquer outro idioma, para o seu. A app é mostrada no seu idioma.",
        startupSection: "Início",
        launchAtLogin: "Abrir ao iniciar sessão",
        launchAtLoginApproval: "Ainda precisa ser permitido em Ajustes do Sistema → Geral → Itens de Início.",
        openLoginItems: "Abrir Itens de Início…",
        launchAtLoginFailed: { "Não foi possível alterar: \($0)" },
        provider: "Fornecedor",
        translateAutomatically: "Traduzir automaticamente",
        variantsSection: "Várias versões",
        automaticFooter: { "\($0) é consultado em cada tradução, junto com o Apple Translation." },
        manualFooter: { "O pop-up mostra um botão para pedir as versões a \($0) (tecla C)." },
        test: "Testar",
        claudeCodeDetails: "Usa a sua sessão do Claude Code; não precisa de chave. Modelo: Claude Haiku 5.5.",
        billedSeparately: "Faturado à parte da sua subscrição.",
        billedByUsage: "Faturado à parte, conforme o uso.",
        keyOptional: "Opcional se o seu servidor não pedir chave.",
        deepLHelp: "As chaves gratuitas terminam em :fx. Dá uma versão formal e outra informal quando o idioma o permite.",
        model: "Modelo",
        apiURL: "URL da API",
        save: "Guardar",
        remove: "Apagar",
        officialURLHelp: "Vazia, usa-se a da OpenAI. Altere-a para usar um servidor compatível (Ollama, OpenRouter, Groq…).",
        compatibleURLHelp: "Servidor compatível: usa-se a sua API Chat Completions. Vazia, volta à OpenAI.",
        invalidURL: "O URL não é válido. Tem de começar por http:// ou https://.",
        modelPlaceholder: "Nome do modelo, p. ex. llama3.2",
        openAIModelsHelp: "Modelos da OpenAI",
        keySaved: "Chave guardada no porta-chaves",
        createKeyAt: { "Criar uma chave em \($0)" },
        getDeepLKey: "Obter uma chave da API DeepL (há um plano gratuito)",
        testSentence: "Olá, vemo-nos amanhã logo de manhã?",
        fastest: "o mais rápido",
        fastestCheapest: "o mais rápido e barato",
        moreQuality: "mais qualidade",
        bestQuality: "a melhor qualidade, mais lento",
        pressNewShortcut: "Prima a nova combinação. Esc para cancelar.",
        shortcutChanged: { "Atalho alterado para \($0)." },
        recordShortcut: "Gravar novo atalho",
        cancel: "Cancelar",
        reset: "Repor",
        resetHelp: { "Voltar a \($0)" },
        spaceKey: "Espaço",
        shortcutUnavailable: { "\($0) não está disponível: outra app ou o sistema usa-o." },
        shortcutNeedsModifier: "O atalho precisa de pelo menos ⌘, ⌥ ou ⌃.",
        shortcutReserved: { "\($0) é um atalho do sistema ou de edição. Escolha outro." },
        cliNotFound: "O CLI quick-translate não foi encontrado (QTNodePath / QTCLIPath no Info.plist).",
        serverStopped: "O processo de tradução parou. Tente novamente.",
        translationFailed: "A tradução falhou.",
        unknownLanguage: "Não foi possível detetar o idioma.",
        alreadyIn: { "O texto já está em \($0)." },
        notInstalled: { "Descarregue \($0) → \($1) para traduzir neste Mac." },
        missingKey: { "Falta a chave de \($0). Adicione-a nas definições." },
        authFailed: { "\($0) rejeitou a chave. Verifique-a nas definições." },
        quotaExceeded: { "A quota de \($0) esgotou-se." },
        rateLimited: { "Demasiados pedidos a \($0). Aguarde um momento." },
        unsupportedLanguage: { "\($0) não suporta este idioma." },
        refused: { "\($0) recusou-se a traduzir este texto." },
        network: { "Não foi possível ligar a \($0)." },
        providerFailed: { "\($0) falhou: \($1)" }
    )
}
