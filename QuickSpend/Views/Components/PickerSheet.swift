import SwiftUI

/// Reusable list-based picker sheet with navigation title, done button, and checkmark selection.
struct PickerSheet<Item: Identifiable>: View {
    let title: String
    let doneText: String
    let items: [Item]
    let selectedId: Item.ID
    let icon: (Item) -> String
    let iconStyle: IconStyle
    let label: (Item) -> String
    let onSelect: (Item) -> Void
    let onDone: () -> Void

    enum IconStyle {
        case plain(Color)
        case custom
    }

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        Text(icon(item))
                            .font(.title2.bold())
                            .foregroundStyle(iconColor)
                            .frame(width: 32, alignment: .center)

                        Text(label(item))
                            .font(.body)

                        Spacer()

                        if item.id == selectedId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(doneText, action: onDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var iconColor: Color {
        switch iconStyle {
        case .plain(let color): return color
        case .custom: return .primary
        }
    }
}
