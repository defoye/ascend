import SwiftUI

/// The chrome for Ascend text fields: `surfaceSecondary` fill, 1px `border`
/// that becomes `primary` when focused (or `danger` on error), `md` corner
/// radius, 46pt height (see docs/design/DESIGN_SPEC.md §3 "Form fields").
public struct AscendTextFieldStyle: TextFieldStyle {
    private let isFocused: Bool
    private let hasError: Bool

    public init(isFocused: Bool = false, hasError: Bool = false) {
        self.isFocused = isFocused
        self.hasError = hasError
    }

    // `_body` is SwiftUI's required `TextFieldStyle` protocol method name.
    // swiftlint:disable:next identifier_name
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .ascendType(.body)
            .foregroundStyle(Color.Ascend.textPrimary)
            .padding(.horizontal, Spacing.space3)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.Ascend.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            )
    }

    private var borderColor: Color {
        if hasError { return Color.Ascend.danger }
        if isFocused { return Color.Ascend.primary }
        return Color.Ascend.border
    }
}

/// A composed field: optional label above, the styled text field, and an
/// optional footnote helper or error message below.
public struct AscendTextField: View {
    private let label: String?
    private let placeholder: String
    private let helperText: String?
    private let errorText: String?
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    public init(
        label: String? = nil,
        placeholder: String = "",
        text: Binding<String>,
        helperText: String? = nil,
        errorText: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.helperText = helperText
        self.errorText = errorText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            if let label {
                Text(label)
                    .ascendType(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Ascend.textSecondary)
            }
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(Color.Ascend.textTertiary)
            )
            .focused($isFocused)
            .textFieldStyle(AscendTextFieldStyle(isFocused: isFocused, hasError: errorText != nil))
            .accessibilityLabel(label ?? placeholder)
            .accessibilityHint(errorText ?? helperText ?? "")
            if let errorText {
                Text(errorText)
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.danger)
            } else if let helperText {
                Text(helperText)
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.textSecondary)
            }
        }
    }
}

#Preview("AscendTextField - Light") {
    AscendTextFieldPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("AscendTextField - Dark") {
    AscendTextFieldPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct AscendTextFieldPreviewGallery: View {
    @State private var name = ""
    @State private var email = "coach@ascend.app"
    @State private var password = ""

    var body: some View {
        VStack(spacing: Spacing.space4) {
            AscendTextField(label: "Full name", placeholder: "Jordan Lee", text: $name, helperText: "Shown on your public profile")
            AscendTextField(label: "Email", text: $email)
            AscendTextField(label: "Password", placeholder: "Required", text: $password, errorText: "Password must be at least 8 characters")
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
