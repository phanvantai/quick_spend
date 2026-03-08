import SwiftUI

/// List of feature requests submitted by premium users
struct FeatureRequestListView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Environment(\.colorScheme) private var colorScheme

    @State private var service = FeatureRequestService()
    @State private var showAddForm = false
    @State private var showMyRequestsOnly = false
    @State private var isAdminMode = false
    @State private var adminTapCount = 0
    @State private var selectedRequest: FeatureRequest?
    @State private var requestToDelete: FeatureRequest?
    @State private var selectedStatusFilter: RequestStatus?
    @State private var expandedRequestId: String?

    private var displayedRequests: [FeatureRequest] {
        var result = showMyRequestsOnly ? service.myRequests() : service.requests
        if let filter = selectedStatusFilter {
            result = result.filter { $0.status == filter }
        }
        return result
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

            // Filters
            Section {
                Toggle(
                    L10n.tr("feature_request.show_mine_only", appConfig.language),
                    isOn: $showMyRequestsOnly
                )
                .tint(AppTheme.adaptiveAccent(colorScheme))

                // Status filter
                statusFilterRow()
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        requestToDelete = request
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else if subscription.isPremium {
                            expandableRequestRow(request)
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
        .alert(
            "Delete Request",
            isPresented: Binding(
                get: { requestToDelete != nil },
                set: { if !$0 { requestToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                requestToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let request = requestToDelete {
                    Task {
                        let _ = await service.deleteRequest(requestId: request.id)
                    }
                    requestToDelete = nil
                }
            }
        } message: {
            if let request = requestToDelete {
                Text("Delete \"\(request.title)\"? This cannot be undone.")
            }
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

    // MARK: - Status Filter

    private func statusFilterRow() -> some View {
        HStack {
            Text(L10n.tr("feature_request.filter_by_status", appConfig.language))
                .font(.body)

            Spacer()

            Menu {
                Button {
                    selectedStatusFilter = nil
                } label: {
                    HStack {
                        Text(L10n.tr("feature_request.filter_all", appConfig.language))
                        if selectedStatusFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(RequestStatus.allCases, id: \.self) { status in
                    Button {
                        selectedStatusFilter = status
                    } label: {
                        HStack {
                            Image(systemName: status.iconName)
                            Text(status.displayName(language: appConfig.language))
                            if selectedStatusFilter == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: AppTheme.spacing4) {
                    if let filter = selectedStatusFilter {
                        Image(systemName: filter.iconName)
                            .font(.caption)
                        Text(filter.displayName(language: appConfig.language))
                            .font(.subheadline)
                    } else {
                        Text(L10n.tr("feature_request.filter_all", appConfig.language))
                            .font(.subheadline)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
            }
        }
    }

    // MARK: - Expandable Request Row (Premium)

    private func expandableRequestRow(_ request: FeatureRequest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            requestRow(request)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedRequestId = expandedRequestId == request.id ? nil : request.id
                    }
                }

            if expandedRequestId == request.id {
                requestDetailView(request)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Request Detail View

    private func requestDetailView(_ request: FeatureRequest) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Divider()
                .padding(.top, AppTheme.spacing4)

            // Full description
            if !request.description.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                    Text(L10n.tr("feature_request.detail_description", appConfig.language))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(request.description)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Category
            HStack(spacing: AppTheme.spacing4) {
                Text(L10n.tr("feature_request.detail_category", appConfig.language))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: request.category.iconName)
                    .font(.caption)
                Text(request.category.displayName(language: appConfig.language))
                    .font(.caption)
            }

            // Status
            HStack(spacing: AppTheme.spacing4) {
                Text(L10n.tr("feature_request.detail_status", appConfig.language))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                statusBadge(request.status)
            }

            // Date
            HStack(spacing: AppTheme.spacing4) {
                Text(L10n.tr("feature_request.detail_date", appConfig.language))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(request.createdAt, format: .dateTime.year().month(.wide).day())
                    .font(.caption)
            }

            // Admin response
            if let response = request.adminResponse, !response.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                    Text(L10n.tr("feature_request.detail_response", appConfig.language))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: AppTheme.spacing4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10))
                        Text(response)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                }
            }
        }
        .padding(.top, AppTheme.spacing4)
        .padding(.bottom, AppTheme.spacing8)
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
    @State private var showDeleteConfirmation = false

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

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Request")
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
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
            .alert("Delete Request", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteRequest()
                }
            } message: {
                Text("Delete \"\(request.title)\"? This cannot be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            responseText = request.adminResponse ?? ""
        }
    }

    private func deleteRequest() {
        isUpdating = true
        Task {
            let _ = await service.deleteRequest(requestId: request.id)
            isUpdating = false
            onDismiss()
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
