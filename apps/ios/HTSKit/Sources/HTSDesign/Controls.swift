import SwiftUI

/// Square segmented control: selected segment in `bone` on `surface`, others in `grey-app`. 44 pt tall.
public struct HTSSegmented<Value: Hashable>: View {
    private let options: [(value: Value, label: LocalizedStringKey)]
    @Binding private var selection: Value

    public init(selection: Binding<Value>, options: [(value: Value, label: LocalizedStringKey)]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .htsTextStyle(.bodyStrong)
                        .foregroundStyle(selected ? Color.hts.black : Color.hts.greyApp)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? Color.hts.bone : Color.clear)
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .background(Color.hts.surface)
        .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
    }
}

/// Square stepper: −/+ buttons of 44 pt around the value in the `data` style.
public struct HTSStepper: View {
    private let label: LocalizedStringKey
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let format: (Int) -> String

    public init(
        _ label: LocalizedStringKey, value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1,
        format: @escaping (Int) -> String = { String($0) }
    ) {
        self.label = label
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(spacing: HTSSpacing.space3) {
            Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Spacer()
            button("minus", enabled: value - step >= range.lowerBound) { value -= step }
                .accessibilityLabel("Diminuir")
            Text(verbatim: format(value)).htsTextStyle(.data).foregroundStyle(Color.hts.bone)
                .frame(minWidth: 64)
                .accessibilityHidden(true)
            button("plus", enabled: value + step <= range.upperBound) { value += step }
                .accessibilityLabel("Aumentar")
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(Text(verbatim: format(value)))
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).fontWeight(.light).frame(width: 44, height: 44)
                .overlay(Rectangle().strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair))
        }
        .foregroundStyle(enabled ? Color.hts.bone : Color.hts.tabIdle)
        .disabled(!enabled)
    }
}

/// Date field: shows the day as "02.11.26" and opens an inline calendar below on tap.
public struct HTSDateField: View {
    private let label: LocalizedStringKey
    @Binding private var date: Date
    @State private var open = false

    public init(_ label: LocalizedStringKey, date: Binding<Date>) {
        self.label = label
        _date = date
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            Button {
                open.toggle()
            } label: {
                HStack {
                    Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(verbatim: date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)))
                        .htsTextStyle(.data).foregroundStyle(Color.hts.bone)
                    Image(systemName: open ? "chevron.up" : "chevron.down").fontWeight(.light)
                        .foregroundStyle(Color.hts.bone)
                }
                .frame(minHeight: 44)
            }
            if open {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Color.hts.blood)
                    .padding(HTSSpacing.space2)
                    .background(Color.hts.surface)
                    .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
            }
        }
    }
}
