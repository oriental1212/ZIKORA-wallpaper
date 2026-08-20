import SwiftUI

struct SourceFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SourceFormViewModel

    private let titleKey: LocalizedStringKey

    init(
        repository: any SourceRepository,
        clock: any Clock,
        uuidGenerator: any UUIDGenerating,
        logger: any AppLogging,
        mode: SourceFormMode,
        onSaved: @escaping (SourceID) -> Void
    ) {
        self.titleKey = mode == .create
            ? "source.form.title.add"
            : "source.form.title.edit"
        _model = StateObject(wrappedValue: SourceFormViewModel(
            repository: repository,
            clock: clock,
            uuidGenerator: uuidGenerator,
            logger: logger,
            mode: mode,
            onSaved: onSaved
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.large) {
            Text(titleKey)
                .font(DesignTypography.pageTitle)

            Form {
                Section("source.form.section.details") {
                    TextField("source.form.name", text: nameBinding)
                    TextField("source.form.url", text: urlBinding)
                    Toggle("source.form.enabled", isOn: enabledBinding)
                    validationMessages
                }

                Section("source.form.section.connection") {
                    connectionContent
                }
            }
            .formStyle(.grouped)

            if let saveError = model.saveError {
                Label {
                    saveError.detail.text
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.critical)
            }

            HStack(spacing: DesignSpacing.small) {
                Button("action.cancel") {
                    model.cancelTest()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                ZIKORAButton(
                    "source.form.test",
                    systemImage: "bolt",
                    role: .secondary,
                    phase: testPhase,
                    disabledReason: model.canTest ? nil : model.testDisabledReason,
                    action: model.testConnection
                )

                ZIKORAButton(
                    model.mode == .create ? "source.form.add" : "source.form.save",
                    systemImage: model.mode == .create ? "plus" : "checkmark",
                    role: .primary,
                    phase: model.isSaving ? .loading : (model.saveError == nil ? .idle : .failure),
                    disabledReason: model.canSubmit ? nil : model.saveDisabledReason,
                    action: model.save
                )
            }
        }
        .padding(DesignSpacing.large)
        .frame(width: 560)
        .onChange(of: model.savedSourceID) { _, sourceID in
            if sourceID != nil {
                dismiss()
            }
        }
        .alert(
            "source.form.duplicate-url.title",
            isPresented: Binding(
                get: { model.duplicateURLNeedsConfirmation },
                set: { if !$0 { model.cancelDuplicateURL() } }
            )
        ) {
            Button("source.form.duplicate-url.confirm", role: .destructive) {
                model.confirmDuplicateURLAndSave()
            }
            Button("action.cancel", role: .cancel) {
                model.cancelDuplicateURL()
            }
        } message: {
            Text("source.form.duplicate-url.message")
        }
        .onDisappear {
            model.cancelTest()
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { model.name }, set: { model.setName($0) })
    }

    private var urlBinding: Binding<String> {
        Binding(get: { model.urlText }, set: { model.setURLText($0) })
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { model.isEnabled }, set: { model.setIsEnabled($0) })
    }

    private var testPhase: ZIKORAButtonPhase {
        switch model.connectionState {
        case .loading:
            .loading
        case .failure:
            .failure
        case .idle, .success:
            .idle
        }
    }

    @ViewBuilder
    private var validationMessages: some View {
        ForEach(Array(model.validationIssues.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { issue in
            Label(issue.localizedTitle, systemImage: "exclamationmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.critical)
        }

        if model.duplicateNameWarning {
            Label("source.form.duplicate-name.warning", systemImage: "exclamationmark.triangle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.warning)
        }
    }

    @ViewBuilder
    private var connectionContent: some View {
        switch model.connectionState {
        case .idle:
            Text("source.form.connection.idle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.secondaryText)
        case .loading:
            HStack(spacing: DesignSpacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text("status.loading")
                    .font(DesignTypography.caption)
            }
        case .success(let preview):
            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                if let previewURL = model.validatedURL {
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.title2)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 320, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                            .stroke(DesignColor.separator, lineWidth: 1)
                    }
                }

                HStack(spacing: DesignSpacing.medium) {
                    previewMetadata(
                        title: "source.form.preview.size",
                        value: "\(preview.pixelWidth) × \(preview.pixelHeight)"
                    )
                    previewMetadata(
                        title: "source.form.preview.format",
                        value: sourceFormatIdentifier(preview.formatIdentifier)
                    )
                    previewMetadata(
                        title: "source.form.preview.byte-count",
                        value: ByteCountFormatter.sourcePreview.string(fromByteCount: preview.byteCount)
                    )
                }
            }
        case .failure(let message):
            VStack(alignment: .leading, spacing: DesignSpacing.compact) {
                Label {
                    message.title.text
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(DesignColor.critical)
                message.detail.text
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
    }

    private func previewMetadata(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.compact) {
            Text(title)
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.secondaryText)
            Text(verbatim: value)
                .font(DesignTypography.monospacedMetadata)
        }
    }
}

private extension SourceInputIssue {
    var rawValue: String {
        switch self {
        case .nameRequired:
            "0-name-required"
        case .nameTooLong:
            "1-name-too-long"
        case .invalidURL:
            "2-invalid-url"
        case .connectionTestRequired:
            "3-connection-test-required"
        case .duplicateURLConfirmationRequired:
            "4-duplicate-url-confirmation"
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .nameRequired:
            "source.form.name.required"
        case .nameTooLong:
            "source.form.name.too-long"
        case .invalidURL:
            "source.form.url.invalid"
        case .connectionTestRequired:
            "source.form.test.required"
        case .duplicateURLConfirmationRequired:
            "source.form.duplicate-url.required"
        }
    }
}
