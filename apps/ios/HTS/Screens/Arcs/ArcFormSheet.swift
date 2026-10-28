import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Create or edit an arc: name, kanji, program, kind, start, weeks and templates, with a live summary.
struct ArcFormSheet: View {
    let model: ArcsModel
    let target: ArcsScreen.EditTarget

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ArcDraft?
    @State private var reusable: [(arc: Arc, template: WorkoutTemplate)] = []
    @State private var confirmRestart = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let draft = Binding($draft) {
                    form(draft)
                        .padding(.horizontal, HTSSpacing.space5)
                        .padding(.vertical, HTSSpacing.space4)
                }
            }
            .background(Color.hts.black)
            .navigationTitle(isNew ? "Criar arco" : "Editar arco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.tint(Color.hts.bone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { Task { await save() } }
                        .tint(Color.hts.bone)
                        .disabled(!(draft?.isValid ?? false) || saving)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            switch target {
            case .new: draft = model.newDraft()
            case .arc(let id): draft = await model.draft(for: id)
            }
            reusable = await model.reusableTemplates(excluding: draft?.arcId)
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    @ViewBuilder private func form(_ draft: Binding<ArcDraft>) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space7) {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                HTSTextField(label: "NOME", text: draft.name, prompt: "Recrutamento")
                HTSTextField(label: "KANJI (OPCIONAL)", text: draft.kanji, prompt: "募")
                HTSTextField(label: "PROGRAMA DO PREPARADOR (OPCIONAL)", text: draft.program)
            }

            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                FieldLabel(text: "TIPO")
                Picker("Tipo", selection: draft.kind) {
                    Text("Normal").tag(ArcKind.normal)
                    Text("Especial").tag(ArcKind.special)
                    Text("Manutenção").tag(ArcKind.filler)
                }
                .pickerStyle(.segmented)
            }

            if draft.wrappedValue.hasDuration {
                VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                    DatePicker(
                        selection: Binding(
                            get: { draft.wrappedValue.startDate.date },
                            set: { draft.wrappedValue.startDate = LocalDate($0, in: .current) }),
                        displayedComponents: .date
                    ) { FieldLabel(text: "INÍCIO") }
                    Stepper(value: draft.weeks, in: 1...52) {
                        HStack {
                            FieldLabel(text: "SEMANAS")
                            Spacer()
                            Text(verbatim: "\(draft.wrappedValue.weeks)").htsTextStyle(.data)
                        }
                    }
                }
            }

            templates(draft)
            summary(draft.wrappedValue)

            if !isNew, let arcId = draft.wrappedValue.arcId {
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    HTSButton("Recomeçar contagem", kind: .ghost) { confirmRestart = true }
                    Text("Zera o progresso do arco. O histórico de treinos continua.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
                .confirmationDialog("Recomeçar a contagem deste arco?", isPresented: $confirmRestart) {
                    Button("Recomeçar contagem", role: .destructive) {
                        Task {
                            await model.restartCount(arcId: arcId)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func templates(_ draft: Binding<ArcDraft>) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            FieldLabel(text: "TREINOS")
            ForEach(Array(draft.wrappedValue.templates.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: HTSSpacing.space3) {
                    Text(verbatim: TemplateLetter.letter(at: index)).htsTextStyle(.data)
                        .frame(width: 32)
                    TextField(
                        "Nome do treino",
                        text: Binding(
                            get: { draft.wrappedValue.templates[index].name },
                            set: { draft.wrappedValue.templates[index].name = $0 })
                    )
                    .htsTextStyle(.body)
                    .padding(.horizontal, HTSSpacing.space3)
                    .frame(minHeight: 44)
                    .background(Color.hts.surface)
                    .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
                    Button {
                        draft.wrappedValue.templates.swapAt(index, index - 1)
                    } label: {
                        Image(systemName: "arrow.up").frame(width: 44, height: 44)
                    }
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0 : 1)
                    .accessibilityHidden(index == 0)
                    .accessibilityLabel("Subir \(item.name)")
                    Button {
                        draft.wrappedValue.templates.remove(at: index)
                    } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remover \(item.name)")
                }
                .fontWeight(.light)
                .foregroundStyle(Color.hts.bone)
            }
            HStack(spacing: HTSSpacing.space3) {
                HTSButton("Adicionar treino", kind: .ghost) {
                    draft.wrappedValue.templates.append(.init(origin: .new, name: ""))
                }
                if !reusable.isEmpty {
                    Menu {
                        ForEach(reusable, id: \.template.id) { item in
                            Button("\(item.arc.name) · \(item.template.letter) · \(item.template.name)") {
                                draft.wrappedValue.templates.append(
                                    .init(
                                        origin: .reuse(item.template.id), name: item.template.name,
                                        focus: item.template.focus))
                            }
                        }
                    } label: {
                        Text("Reaproveitar treino").frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(HTSButtonStyle(.ghost))
                }
            }
        }
    }

    @ViewBuilder private func summary(_ draft: ArcDraft) -> some View {
        let schedule = draft.schedule
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                FieldLabel(text: "RESUMO")
                if let total = schedule.totalSessions, let end = schedule.endDate {
                    summaryRow("Total", "\(total) treinos")
                    summaryRow("Ritmo", "\(schedule.weeklyGoal) por semana")
                    summaryRow("Término", "\(end.short)")
                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                        ForEach(Array(schedule.weekGrid.enumerated()), id: \.offset) { week, letters in
                            Text(verbatim: String(format: "S%02d  ", week + 1) + letters.joined(separator: " "))
                                .htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                        }
                    }
                } else {
                    summaryRow("Ritmo", "\(schedule.weeklyGoal) por semana")
                    Text("Sem prazo. Conta para a sequência semanal.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
        }
    }

    private func summaryRow(_ label: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack {
            Text(label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            Spacer()
            Text(value).htsTextStyle(.dataSm).foregroundStyle(Color.hts.bone)
        }
    }

    private func save() async {
        guard let draft else { return }
        saving = true
        if await model.save(draft) { dismiss() }
        saving = false
    }
}
