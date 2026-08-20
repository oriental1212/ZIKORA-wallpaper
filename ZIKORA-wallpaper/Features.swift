import SwiftUI

struct OnboardingView: View {
    @Environment(\.appEnvironment) private var environment
    @AppStorage("onboarding.source.name") private var name = "My first source"
    @AppStorage("onboarding.source.url") private var urlText = ""
    @State private var isTesting = false
    @State private var testResult: SourceConnectionTestResult?
    @State private var errorText: String?
    let onCompleted: () -> Void

    var body: some View {
        VStack(spacing: DesignSpacing.large) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(DesignColor.primaryAction)
                .accessibilityHidden(true)
            VStack(spacing: DesignSpacing.small) {
                Text("onboarding.welcome")
                    .font(DesignTypography.pageTitle)
                Text("onboarding.subtitle")
                    .foregroundStyle(DesignColor.secondaryText)
            }
            VStack(alignment: .leading, spacing: DesignSpacing.medium) {
                TextField("onboarding.source-name", text: $name)
                TextField("onboarding.image-url", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                if let testResult {
                    Label {
                        Text("onboarding.verified-prefix")
                        Text(verbatim: "\(testResult.preview.pixelWidth) × \(testResult.preview.pixelHeight)")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                        .foregroundStyle(DesignColor.success)
                        .accessibilityLabel("onboarding.verified")
                }
                if let errorText {
                    Label(LocalizedStringKey(errorText), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignColor.critical)
                }
                HStack {
                    Button(isTesting ? "status.loading" : "onboarding.test-connection") { testConnection() }
                        .disabled(isTesting || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || urlText.isEmpty)
                    Spacer()
                    Button("action.continue") { complete() }
                        .buttonStyle(.borderedProminent)
                        .disabled(testResult == nil)
                }
            }
            .frame(maxWidth: 520)
            .padding(DesignSpacing.large)
            .designSurface(.card)
            Spacer()
        }
        .padding(DesignSpacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: name) { _, _ in testResult = nil }
        .onChange(of: urlText) { _, _ in testResult = nil }
    }

    private func testConnection() {
        guard environment.repository != nil else { return }
        testResult = nil
        errorText = nil
        isTesting = true
        let input = SourceFormInput(name: name, urlText: urlText, isEnabled: true)
        Task {
            do {
                let result = try await TestSourceConnectionUseCase(
                    downloader: URLSessionImageDownloader(logger: environment.logger),
                    validator: ImageIOImageValidator(),
                    clock: environment.clock
                ).execute(input: input)
                testResult = result
            } catch {
                errorText = "onboarding.error.connection"
            }
            isTesting = false
        }
    }

    private func complete() {
        guard let repository = environment.repository, let testResult else { return }
        Task {
            let now = await environment.clock.now()
            do {
                let source = try await SaveSourceUseCase(
                    sources: repository,
                    clock: environment.clock,
                    uuidGenerator: environment.uuidGenerator
                ).execute(
                    input: SourceFormInput(name: name, urlText: urlText, isEnabled: true),
                    context: .create,
                    connectionProof: testResult.proof
                )
                let schedule = WeeklySchedule(
                    id: await environment.uuidGenerator.makeUUID(),
                    mondaySourceID: source.id, tuesdaySourceID: source.id,
                    wednesdaySourceID: source.id, thursdaySourceID: source.id,
                    fridaySourceID: source.id, saturdaySourceID: source.id,
                    sundaySourceID: source.id, defaultSourceID: source.id,
                    updatedAt: now
                )
                try await repository.save(schedule)
                var settings = UserSettings.defaults(id: await environment.uuidGenerator.makeUUID(), updatedAt: now)
                settings.onboardingCompleted = true
                try await repository.save(settings)
                UserDefaults.standard.removeObject(forKey: "onboarding.source.name")
                UserDefaults.standard.removeObject(forKey: "onboarding.source.url")
                onCompleted()
            } catch {
                errorText = "onboarding.error.save"
            }
        }
    }
}
