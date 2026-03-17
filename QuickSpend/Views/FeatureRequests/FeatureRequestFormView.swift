import SwiftUI

/// Form for submitting a new feature request
struct FeatureRequestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let service: FeatureRequestService
    let isPremium: Bool

    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: RequestCategory = .newFeature
    @State private var isSubmitting = false
    @State private var showTitleError = false

    var body: some View {
        NavigationStack {
            Form {
                // Category picker
                Section(L10n.tr("feature_request.category_section", appConfig.language)) {
                    Picker(
                        L10n.tr("feature_request.category_section", appConfig.language),
                        selection: $selectedCategory
                    ) {
                        ForEach(RequestCategory.allCases, id: \.self) { cat in
                            Label(
                                cat.displayName(language: appConfig.language),
                                systemImage: cat.iconName
                            )
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Title
                Section(L10n.tr("feature_request.title_section", appConfig.language)) {
                    TextField(
                        L10n.tr("feature_request.title_placeholder", appConfig.language),
                        text: $title
                    )
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: title) {
                        showTitleError = false
                        if title.count > AppConstants.maxFeatureRequestTitleLength {
                            title = String(title.prefix(AppConstants.maxFeatureRequestTitleLength))
                        }
                    }

                    if showTitleError {
                        Text(L10n.tr("feature_request.title_required", appConfig.language))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Description
                Section(L10n.tr("feature_request.description_section", appConfig.language)) {
                    TextField(
                        L10n.tr("feature_request.description_placeholder", appConfig.language),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: description) {
                        if description.count > AppConstants.maxFeatureRequestDescriptionLength {
                            description = String(description.prefix(AppConstants.maxFeatureRequestDescriptionLength))
                        }
                    }

                    Text("\(description.count)/\(AppConstants.maxFeatureRequestDescriptionLength)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle(L10n.tr("feature_request.new_title", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { submit() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            showTitleError = true
            return
        }
        showTitleError = false
        isSubmitting = true

        Task {
            let success = await service.submitRequest(
                title: trimmedTitle,
                description: description.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                language: appConfig.language,
                isPremium: isPremium
            )
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

#Preview {
    FeatureRequestFormView(service: FeatureRequestService(), isPremium: false)
        .environment(AppConfigViewModel())
}
