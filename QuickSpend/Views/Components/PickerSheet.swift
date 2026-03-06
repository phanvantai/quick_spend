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
        /// Renders the icon string as an SF Symbol via Image(systemName:)
        case sfSymbol(Color)
    }

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        iconView(for: item)
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

    @ViewBuilder
    private func iconView(for item: Item) -> some View {
        switch iconStyle {
        case .sfSymbol(let color):
            Image(systemName: icon(item))
                .font(.title3)
                .foregroundStyle(color)
        case .plain(let color):
            Text(icon(item))
                .font(.title2.bold())
                .foregroundStyle(color)
        case .custom:
            Text(icon(item))
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
    }
}
