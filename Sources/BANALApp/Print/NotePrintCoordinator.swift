import AppKit
import BANALCore
import BANALPublisher
import Foundation

/// Coordinates native macOS printing operations for BANAL notes and recipes.
@MainActor
public enum NotePrintCoordinator {

    /// Constructs an `NSPrintOperation` configured for the given note and display mode.
    public static func makePrintOperation(
        for note: Note,
        isRecipeReadMode: Bool = false,
        oliverRecipe: OliverRecipe? = nil,
        scale: RecipeScale = .one
    ) -> NSPrintOperation {
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36

        var recipeModel: NotePreviewGenerator.RecipePreviewModel?
        if let oliverRecipe {
            let ing = oliverRecipe.ingredientIndex.map {
                NotePreviewGenerator.RecipeIngredient(
                    name: $0.name,
                    quantity: $0.quantity,
                    unit: $0.units,
                    isSauceReference: false
                )
            }
            let cw = oliverRecipe.cookwareIndex.map(\.name)
            var steps: [String] = []
            for block in oliverRecipe.blocks {
                switch block {
                case .section(let name):
                    if !name.isEmpty { steps.append(name) }
                case .step(let parts):
                    steps.append(parts.map(\.inlineText).joined())
                case .note(let text):
                    steps.append(text)
                }
            }
            recipeModel = NotePreviewGenerator.RecipePreviewModel(
                title: note.displayTitle,
                metadata: [:],
                tags: note.tags,
                ingredients: ing,
                cookware: cw,
                steps: steps
            )
        }

        let attributed = NotePrintFormatter.attributedString(
            for: note,
            isRecipeReadMode: isRecipeReadMode,
            recipeModel: recipeModel,
            scaleLabel: scale.label
        )

        let printableWidth = max(200, printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin)
        let printableHeight = max(200, printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: printableWidth, height: printableHeight))
        textView.appearance = NSAppearance(named: .aqua)
        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: printableWidth, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(attributed)

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation
    }

    /// Displays the macOS print dialog for the given note.
    public static func printNote(
        _ note: Note,
        isRecipeReadMode: Bool = false,
        oliverRecipe: OliverRecipe? = nil,
        scale: RecipeScale = .one,
        window: NSWindow? = nil
    ) {
        let operation = makePrintOperation(
            for: note,
            isRecipeReadMode: isRecipeReadMode,
            oliverRecipe: oliverRecipe,
            scale: scale
        )

        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        if let targetWindow {
            operation.runModal(for: targetWindow, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
