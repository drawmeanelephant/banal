import BANALPublisher
import SwiftUI

struct RecipeReadView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scalePicker
                if let error = model.recipeError {
                    Text(error)
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                } else if let recipe = model.oliverRecipe {
                    ingredientList(recipe)
                    cookwareList(recipe)
                    method(recipe)
                }
            }
            .padding(.horizontal, EditorTypography.horizontalInset)
            .padding(.top, 4)
            .padding(.bottom, 36)
            .frame(maxWidth: measure)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recipe")
    }

    private var measure: CGFloat? {
        model.preferences.limitLineLength ? EditorTypography.measureWidth : nil
    }

    private var bodyFont: Font {
        EditorTypography.swiftUIFont(size: model.preferences.fontSize, weight: .regular)
    }

    private var scalePicker: some View {
        Picker("Scale", selection: Binding(
            get: { model.recipeScale },
            set: { model.setRecipeScale($0) }
        )) {
            ForEach(RecipeScale.allCases) { scale in
                Text(scale.label).tag(scale)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: 220)
        .accessibilityLabel("Scale")
    }

    @ViewBuilder
    private func ingredientList(_ recipe: OliverRecipe) -> some View {
        let items = recipe.ingredientIndex
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeading("Ingredients")
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.amountText ?? "")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 56, alignment: .trailing)
                        Text(item.name + preparationSuffix(item.preparation))
                    }
                    .font(bodyFont)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.displayLine)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Ingredients")
        }
    }

    @ViewBuilder
    private func cookwareList(_ recipe: OliverRecipe) -> some View {
        let items = recipe.cookwareIndex
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeading("Cookware")
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item.name)
                        .font(bodyFont)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cookware")
        }
    }

    @ViewBuilder
    private func method(_ recipe: OliverRecipe) -> some View {
        let items = numberedItems(recipe.blocks)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .heading(let name):
                        Text(name)
                            .font(.headline)
                            .padding(.top, 8)
                    case .step(let number, let text):
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(number).")
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                            Text(text)
                        }
                        .font(bodyFont)
                    case .note(let text):
                        Text(text)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.leading, 32)
                            .font(bodyFont)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Steps")
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func preparationSuffix(_ preparation: String?) -> String {
        guard let preparation, !preparation.isEmpty else { return "" }
        return " (\(preparation))"
    }

    private func numberedItems(_ blocks: [OliverRecipeBlock]) -> [ReadingItem] {
        var items: [ReadingItem] = []
        var number = 1
        for block in blocks {
            switch block {
            case .section(let name):
                if !name.isEmpty {
                    items.append(.heading(name))
                }
                number = 1
            case .step(let parts):
                items.append(.step(number, parts.map(\.inlineText).joined()))
                number += 1
            case .note(let text):
                items.append(.note(text))
            }
        }
        return items
    }
}

private enum ReadingItem {
    case heading(String)
    case step(Int, String)
    case note(String)
}
