import Foundation

struct PromptPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var instruction: String

    init(id: UUID = UUID(), name: String, instruction: String) {
        self.id = id
        self.name = name
        self.instruction = instruction
    }

    static let raw = PromptPreset(
        name: "Raw (kein LLM)",
        instruction: ""
    )

    static let defaults: [PromptPreset] = [
        raw,
        PromptPreset(
            name: "Clean-up",
            instruction: """
            Du bekommst einen diktierten Text. Entferne Füllwörter (ähm, äh, also, quasi), \
            korrigiere kleine grammatikalische Stolperer, aber behalte Wortwahl und Ton exakt bei. \
            Gib ausschließlich den überarbeiteten Text zurück, ohne Kommentare.
            """
        ),
        PromptPreset(
            name: "E-Mail",
            instruction: """
            Formuliere den folgenden diktierten Inhalt als freundliche, professionelle E-Mail \
            in der Sprache des Originals. Füge eine passende Anrede und Grußformel hinzu. \
            Gib nur die E-Mail zurück, keine Erklärungen.
            """
        ),
        PromptPreset(
            name: "Stichpunkte",
            instruction: """
            Wandle den diktierten Text in eine prägnante Stichpunkt-Liste um. \
            Eine Zeile pro Gedanke, mit Bullet-Zeichen "•". Keine Einleitung, keine Erklärung.
            """
        ),
        PromptPreset(
            name: "Auf Englisch übersetzen",
            instruction: """
            Translate the following dictated text to natural, fluent English. \
            Preserve tone and register. Return only the translation, no commentary.
            """
        )
    ]
}
