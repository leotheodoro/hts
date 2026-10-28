import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Edits a workout template: blocks (kind, attributes, round duration) and exercises (sets × target, own rest).
struct TemplateEditorSheet: View {
    let database: AppDatabase
    let athleteId: UUID
    let templateId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TemplateDraft?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let draft = Binding($draft) {
                    VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                        HTSTextField(label: "NOME", text: draft.name)
                        HTSTextField(label: "FOCO (OPCIONAL)", text: draft.focus, prompt: "Força e explosão")
                        ForEach(draft.blocks) { $block in
                            BlockEditor(
                                block: $block, index: index(of: block.id), database: database, athleteId: athleteId,
                                onMoveUp: { move(block.id) }, onRemove: { remove(block.id) })
                        }
                        HTSButton("Adicionar bloco", kind: .ghost) {
                            draft.wrappedValue.blocks.append(.init(exercises: [.init()]))
                        }
                        if let error {
                            Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                        }
                    }
                    .padding(.horizontal, HTSSpacing.space5)
                    .padding(.vertical, HTSSpacing.space4)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.hts.black)
            .navigationTitle(draft.map { "\($0.letter) · \($0.name)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.tint(Color.hts.bone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { Task { await save() } }
                        .tint(Color.hts.bone)
                        .disabled(!(draft?.isValid ?? false))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { draft = try? await TemplateService(database).draft(templateId: templateId) }
    }

    private func index(of id: UUID) -> Int {
        draft?.blocks.firstIndex { $0.id == id } ?? 0
    }

    private func move(_ id: UUID) {
        let i = index(of: id)
        guard i > 0 else { return }
        draft?.blocks.swapAt(i, i - 1)
    }

    private func remove(_ id: UUID) {
        draft?.blocks.removeAll { $0.id == id }
    }

    private func save() async {
        guard let draft else { return }
        do {
            try await TemplateService(database).save(draft)
            dismiss()
        } catch {
            self.error = String(describing: error)
        }
    }
}

private struct BlockEditor: View {
    @Binding var block: TemplateDraft.BlockDraft
    let index: Int
    let database: AppDatabase
    let athleteId: UUID
    let onMoveUp: () -> Void
    let onRemove: () -> Void

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                HStack(spacing: HTSSpacing.space2) {
                    Text(verbatim: String(format: "BLOCO %02d", index + 1)).htsTextStyle(.label)
                        .foregroundStyle(Color.hts.grey)
                    Spacer()
                    if index > 0 {
                        IconButton(symbol: "arrow.up", label: "Subir bloco", action: onMoveUp)
                    }
                    IconButton(symbol: "xmark", label: "Remover bloco", action: onRemove)
                }
                Menu {
                    ForEach(BlockKind.allCases, id: \.self) { kind in
                        Button(kind.label) { block.kind = kind }
                    }
                } label: {
                    HStack {
                        Text(block.kind.label).htsTextStyle(.uiSection)
                        Image(systemName: "chevron.down").fontWeight(.light)
                    }
                    .foregroundStyle(Color.hts.bone)
                    .frame(minHeight: 44)
                }
                HStack(spacing: HTSSpacing.space2) {
                    ForEach(Attribute.allCases, id: \.self) { attribute in
                        AttributeChip(attribute: attribute, selected: block.attributes.contains(attribute)) {
                            if let i = block.attributes.firstIndex(of: attribute) {
                                block.attributes.remove(at: i)
                            } else {
                                block.attributes.append(attribute)
                            }
                        }
                    }
                }
                if block.kind == .fightRound {
                    HTSStepper("DURAÇÃO", value: $block.durationMinutes, in: 1...60) { "\($0) min" }
                }
                ForEach($block.exercises) { $exercise in
                    Divider().overlay(Color.hts.line)
                    ExerciseEditor(exercise: $exercise, database: database, athleteId: athleteId) {
                        block.exercises.removeAll { $0.id == exercise.id }
                    }
                }
                HTSButton("Adicionar exercício", kind: .ghost) {
                    block.exercises.append(.init())
                }
            }
        }
    }
}

private struct ExerciseEditor: View {
    @Binding var exercise: TemplateDraft.ExerciseDraft
    let database: AppDatabase
    let athleteId: UUID
    let onRemove: () -> Void

    @State private var suggestions: [Exercise] = []
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            HStack(spacing: HTSSpacing.space2) {
                TextField("Exercício", text: $exercise.name)
                    .focused($nameFocused)
                    .htsTextStyle(.bodyStrong)
                    .foregroundStyle(Color.hts.bone)
                    .frame(minHeight: 44)
                    .textInputAutocapitalization(.words)
                IconButton(symbol: "xmark", label: "Remover exercício", action: onRemove)
            }
            if nameFocused && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            exercise.name = suggestion.name
                            exercise.unit = suggestion.unit
                            nameFocused = false
                        } label: {
                            Text(verbatim: suggestion.name).htsTextStyle(.body).foregroundStyle(Color.hts.bone)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, HTSSpacing.space3)
                .background(Color.hts.black)
                .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
            }
            HStack(spacing: HTSSpacing.space2) {
                SmallField(label: "SÉRIES", text: $exercise.setsText, keyboard: .numbersAndPunctuation)
                    .frame(width: 72)
                SmallField(label: "ALVO", text: $exercise.targetText, prompt: "8", keyboard: .numbersAndPunctuation)
                Menu {
                    ForEach(ExerciseUnit.allCases, id: \.self) { unit in
                        Button(unit.shortLabel) { exercise.unit = unit }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                        FieldLabel(text: "UNID.")
                        Text(exercise.unit.shortLabel).htsTextStyle(.dataSm).foregroundStyle(Color.hts.bone)
                            .frame(minHeight: 44)
                    }
                }
                .frame(width: 56)
                SmallField(
                    label: "DESC.",
                    text: Binding(
                        get: { exercise.restSeconds.map(String.init) ?? "" },
                        set: { exercise.restSeconds = Int($0) }),
                    prompt: "90", keyboard: .numberPad
                )
                .frame(width: 64)
            }
            Group {
                if !exercise.targetText.isEmpty && exercise.parsed == nil {
                    Text("Alvo inválido. Use 8, 6-6-3-3, 12/12, 10-20 ou máx.").foregroundStyle(Color.hts.redText)
                } else if let hint = exercise.loadHint {
                    Text(verbatim: hint.label).foregroundStyle(Color.hts.greyApp)
                }
            }
            .htsTextStyle(.caption)
        }
        .task(id: exercise.name) {
            guard nameFocused, exercise.name.count >= 2 else {
                suggestions = []
                return
            }
            let found =
                (try? await ExerciseCatalog(database).search(exercise.name, athleteId: athleteId, limit: 3)) ?? []
            suggestions = found.filter { ExerciseName.normalize($0.name) != ExerciseName.normalize(exercise.name) }
        }
    }
}

private struct SmallField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            FieldLabel(text: label)
            TextField(text: $text, prompt: Text(prompt).foregroundStyle(Color.hts.tabIdle)) { Text(label) }
                .keyboardType(keyboard)
                .htsTextStyle(.dataSm)
                .foregroundStyle(Color.hts.bone)
                .padding(.horizontal, HTSSpacing.space2)
                .frame(minHeight: 44)
                .background(Color.hts.black)
                .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
        }
    }
}

private struct AttributeChip: View {
    let attribute: Attribute
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: attribute.abbreviation)
                .htsTextStyle(.label)
                .foregroundStyle(selected ? Color.hts.oliveInk : Color.hts.greyApp)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.hts.olive : Color.clear)
                .overlay(Rectangle().strokeBorder(selected ? Color.clear : Color.hts.line, lineWidth: HTSStroke.hair))
        }
        .accessibilityLabel(attribute.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct IconButton: View {
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).fontWeight(.light).frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.hts.bone)
        .accessibilityLabel(label)
    }
}
