import SwiftUI

/// List of feature requests submitted by premium users
struct FeatureRequestListView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(\.colorScheme) private var colorScheme

    @State private var service = FeatureRequestService()
    @State private var showAddForm = false
    @State private var showMyRequestsOnly = false
    @State private var isAdminMode = false
    @State private var adminTapCount = 0
    @State private var selectedRequest: FeatureRequest?

    private var displayedRequests: [FeatureRequest] {
        showMyRequestsOnly ? service.myRequests() : service.requests
    }

    var body: some View {
        List {
            // Admin mode indicator
            if isAdminMode {
                Section {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(AppTheme.error)
                        Text("Admin Mode")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.error)
                        Spacer()
                        Button("Exit") {
                            isAdminMode = false
                        }
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.error)
                    }
                }
            }

            // Filter toggle
            Section {
                Toggle(
                    L10n.tr("feature_request.show_mine_only", appConfig.language),
                    isOn: $showMyRequestsOnly
                )
                .tint(AppTheme.adaptiveAccent(colorScheme))
            }

            // Requests
            if service.isLoading && service.requests.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            } else if displayedRequests.isEmpty {
                Section {
                    ContentUnavailableView(
                        L10n.tr("feature_request.no_requests", appConfig.language),
                        systemImage: "lightbulb",
                        description: Text(
                            L10n.tr("feature_request.no_requests_desc", appConfig.language)
                        )
                    )
                }
            } else {
                Section(
                    "\(L10n.tr("feature_request.all_requests", appConfig.language)) (\(displayedRequests.count))"
                ) {
                    ForEach(displayedRequests) { request in
                        if isAdminMode {
                            requestRow(request)
                                .onTapGesture {
                                    selectedRequest = request
                                }
                        } else {
                            requestRow(request)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("feature_request.title", appConfig.language))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.tr("feature_request.title", appConfig.language))
                    .font(.headline)
                    .onTapGesture(count: AppConstants.adminModeActivationTaps) {
                        isAdminMode.toggle()
                        adminTapCount = 0
                    }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            FeatureRequestFormView(service: service)
        }
        .sheet(item: $selectedRequest) { request in
            adminStatusPicker(for: request)
        }
        .refreshable {
            await service.fetchRequests()
        }
        .task {
            await service.fetchRequests()
        }
    }

    // MARK: - Request Row

    private func requestRow(_ request: FeatureRequest) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: request.category.iconName,
                color: request.status.color,
                size: 40,
                iconFont: .body
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                    .font(.body)
                    .lineLimit(1)

                if !request.description.isEmpty {
                    Text(request.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let response = request.adminResponse, !response.isEmpty {
                    HStack(spacing: AppTheme.spacing4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 9))
                        Text(response)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                }

                HStack(spacing: AppTheme.spacing4) {
                    statusBadge(request.status)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(request.createdAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if request.userId == service.currentUserId {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(L10n.tr("feature_request.mine", appConfig.language))
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Admin Status Picker

    private func adminStatusPicker(for request: FeatureRequest) -> some View {
        AdminEditRequestSheet(
            request: request,
            service: service,
            language: appConfig.language,
            onDismiss: { selectedRequest = nil }
        )
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: RequestStatus) -> some View {
        HStack(spacing: 2) {
            Image(systemName: status.iconName)
                .font(.system(size: 8))
            Text(status.displayName(language: appConfig.language))
                .font(.caption2.bold())
        }
        .padding(.horizontal, AppTheme.spacing8)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(status.color.opacity(0.15))
        }
        .foregroundStyle(status.color)
    }
}

// MARK: - Admin Edit Request Sheet

private struct AdminEditRequestSheet: View {
    let request: FeatureRequest
    let service: FeatureRequestService
    let language: String
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStatus: RequestStatus
    @State private var responseText: String = ""
    @State private var isUpdating = false

    init(request: FeatureRequest, service: FeatureRequestService, language: String, onDismiss: @escaping () -> Void) {
        self.request = request
        self.service = service
        self.language = language
        self.onDismiss = onDismiss
        _selectedStatus = State(initialValue: request.status)
    }

    private var hasChanges: Bool {
        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalResponse = request.adminResponse ?? ""
        return selectedStatus != request.status || trimmedResponse != originalResponse
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(request.title)
                        .font(.headline)
                    if !request.description.isEmpty {
                        Text(request.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Response") {
                    TextField("Add a reply...", text: $responseText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Status") {
                    ForEach(RequestStatus.allCases, id: \.self) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            HStack(spacing: AppTheme.spacing12) {
                                Image(systemName: status.iconName)
                                    .foregroundStyle(status.color)
                                    .frame(width: 24)
                                Text(status.displayName(language: language))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if status == selectedStatus {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                                        .bold()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close", language)) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.confirm", language)) {
                        confirmChanges()
                    }
                    .bold()
                    .disabled(!hasChanges || isUpdating)
                }
            }
            .overlay {
                if isUpdating {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .tint(AppTheme.adaptiveAccent(colorScheme))
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            responseText = request.adminResponse ?? ""
        }
    }

    private func confirmChanges() {
        isUpdating = true
        Task {
            let response = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            let _ = await service.updateRequestStatus(
                requestId: request.id,
                newStatus: selectedStatus,
                response: response.isEmpty ? nil : response
            )
            isUpdating = false
            onDismiss()
        }
    }
}

#Preview {
    NavigationStack {
        FeatureRequestListView()
            .environment(AppConfigViewModel())
            .environment(SubscriptionViewModel())
    }
}
