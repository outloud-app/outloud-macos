import SwiftUI

struct SheetFrame<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(AppFont.ui(25, weight: .semibold)).tracking(-0.6)
                Text(subtitle).font(AppFont.ui(12)).foregroundStyle(Palette.secondary).lineSpacing(4)
            }
            content
        }.padding(30)
        }.frame(width: 510).frame(maxHeight: 700).fixedSize(horizontal: false, vertical: true).background(Palette.background)
            .foregroundStyle(Palette.text).preferredColorScheme(.light).tint(Palette.mint)
    }
}

struct FormInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(AppFont.ui(11, weight: .medium)).foregroundStyle(Palette.secondary)
            Group {
                if multiline { TextField(placeholder, text: $text, axis: .vertical).lineLimit(3...5) }
                else { TextField(placeholder, text: $text) }
            }.textFieldStyle(.plain).font(AppFont.ui(13)).padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.border))
        }
    }
}

struct ProjectForm: View {
    @Bindable var store: WorkspaceStore
    var existingProject: Project? = nil
    var expansion: Namespace.ID? = nil
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var name = ""
    @State private var description = ""
    @State private var audience = ""
    @State private var website = ""
    @State private var color: BrandColor = .mint
    @State private var productPlatform = "Mac"
    @State private var launchStatus = "launched"
    @State private var keywords = ""
    @State private var showingKeywordHelp = false
    @State private var competitors = ""
    @State private var readingMetadata = false
    @State private var metadataError: String?
    private var normalizedWebsite: String {
        let value = website.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.contains("://") ? value : "https://" + value
    }
    private func entries(_ value: String, separator: String, limit: Int) -> [String] {
        Array(value.components(separatedBy: separator).map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240)) }.filter { !$0.isEmpty }.prefix(limit))
    }
    @State private var step = 0
    @State private var question = 0
    @State private var metadataRead = false
    @State private var category = ""
    @State private var iconURL: String?
    @State private var iconData: Data?
    @State private var manualEntry = false
    @State private var manualQuestion = 0
    @State private var history = SetupStepHistory()
    @State private var connectorFill: CGFloat = 0
    @State private var advancing = false
    @State private var statusProgress: [String: (question: Int, manual: Bool)] = [:]
    @State private var customPlatform = ""
    @State private var enteringPlatform = false
    @FocusState private var customPlatformFocused: Bool
    @State private var metadataRequestID = UUID()
    @FocusState private var platformFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let platforms = ["iOS", "Android", "Web", "Mac", "Windows", "Linux", "HarmonyOS"]
    private let ink = Color(hex: 0x302D27)
    private let accent = Color(hex: 0x7964CF)
    private var platformName: String { productPlatform == "Mac" ? "macOS" : productPlatform }
    private var validDetails: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && name.count <= 70
        && description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 30
        && description.count <= 1200 && !audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && audience.count <= 240 && website.count <= 500 && ResearchKeywords.valid(keywords)
    }
    private var usesLink: Bool { launchStatus == "launched" && !manualEntry }
    private var questionSequence: [Int] { usesLink && metadataRead ? [0, 2, 3, 4, 5] : Array(0...5) }
    private var progressKey: String { launchStatus + (usesLink ? ":link" : ":description") }
    private var currentNumber: Int { (questionSequence.firstIndex(of: question) ?? question) + 1 }
    private var nextQuestionTitle: String {
        usesLink ? (question == 0 ? "Your audience" : question == 2 ? "Research keywords" : question == 3 ? "Competitors" : "Review your app") : ["App name", "The problem it solves", "Your audience", "Research keywords", "Competitors", "Review your app"][min(question + 1, 5)]
    }
    private func goPrevious() {
        question = questionSequence.prefix(while: { $0 != question }).last ?? max(0, question - 1)
        SetupFeedback.selection()
    }
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 52)
            VStack(spacing: 17) {
                HStack(spacing: -5) {
                    ForEach(Array(["iOS", "Android", "Web", "Windows", "Linux"].enumerated()), id: \.offset) { index, item in
                        SetupPlatformBadge(platform: item, size: 44)
                            .rotationEffect(.degrees([-13.0, 5, -5, 10, -8][index]))
                            .offset(y: [4.0, -2, 2, -3, 4][index])
                            .zIndex(Double([1, 3, 5, 4, 2][index]))
                            .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
                    }
                }
                VStack(spacing: 10) {
                    Text("Tell us about your app").font(.system(size: 23, weight: .semibold)).tracking(-0.35)
                    Text(step == 0 ? "Which platform does your app run on?" : "A workspace for your \(platformName) app.")
                        .font(.system(size: 14)).foregroundStyle(ink.opacity(0.52))
                }
            }.padding(.bottom, 30)
            Group { if step == 0 { platformStep } else { questionFlow } }
                .frame(width: 730).id(step).transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
            Spacer(minLength: 42)
        }.frame(width: 850, height: 720)
.background(Color(hex: 0xFAF8F0))
            .foregroundStyle(ink).preferredColorScheme(.light).tint(accent)
            .overlay(alignment: .bottomTrailing) {
                if step == 1 && !history.completed(in: questionSequence, route: progressKey).isEmpty {
                    completedStepNavigation.padding(.trailing, 28).padding(.bottom, 24)
                }
            }
            .overlay(alignment: .topLeading) {
                Button { closeForm() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 30)
                        .background(ink.opacity(0.07), in: Circle())
                }.buttonStyle(.plain).padding(16).help("Back to projects").accessibilityLabel("Back to projects")
            }
            // The native window owns its corner mask throughout the resize.
            .ignoresSafeArea()
            .animation(.easeInOut(duration: reduceMotion ? 0 : 0.28), value: question)
            .onChange(of: website) { _, _ in if metadataRead { metadataRead = false; category = ""; description = "" }; iconURL = nil; iconData = nil; metadataError = nil }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PATH"] != nil,
                   let value = Int(ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_FORM_STEP"] ?? "") {
                    step = value == 0 ? 0 : 1; question = value > 1 ? 2 : 0
                }
                #endif
                guard let project = existingProject else { return }
                name = project.name; description = project.description; audience = project.audience
                website = project.website; color = project.brandColor; iconURL = project.iconURL; iconData = project.iconData
                productPlatform = project.productPlatform ?? "Mac"; launchStatus = project.launchStatus ?? "launched"
                keywords = (project.researchKeywords ?? []).joined(separator: ",")
                competitors = (project.competitors ?? []).joined(separator: "\n")
                manualEntry = true
                step = 1
                question = project.name.count < 2 ? 0 : project.description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 ? 1 : project.audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 2 : !ResearchKeywords.valid(keywords) ? 3 : 5
            }
    }
    private func choose(_ platform: String) {
        SetupFeedback.selection()
        withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.3)) { productPlatform = platform; step = 1 }
    }
    private var platformStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PLATFORM").font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(ink.opacity(0.46))
            HStack(spacing: 8) {
                ForEach(platforms, id: \.self) { platform in
                    Button { choose(platform) } label: {
                        VStack(spacing: 12) {
                            SetupPlatformBadge(platform: platform, size: 35)
                            Text(platform == "Mac" ? "macOS" : platform).font(.system(size: 12, weight: .medium))
                        }.frame(width: 97, height: 100)
                            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(platformFocused && platform == productPlatform ? accent.opacity(0.6) : ink.opacity(0.09), lineWidth: 1))
                    }.buttonStyle(PlatformTileStyle())
                }
            }.focusable().focusEffectDisabled().focused($platformFocused)
                .onMoveCommand { direction in
                    let current = platforms.firstIndex(of: productPlatform) ?? 0
                    let next = direction == .right ? min(platforms.count - 1, current + 1) : direction == .left ? max(0, current - 1) : current
                    productPlatform = platforms[next]; SetupFeedback.selection()
                }
                .onKeyPress(.return) { choose(productPlatform); return .handled }
            Text("Other").font(.system(size: 11)).foregroundStyle(ink.opacity(0.5)).padding(.top, 10)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(ink.opacity(0.45))
                OtherPlatformSelector(text: $customPlatform, editing: $enteringPlatform, select: choose, submit: confirmCustomPlatform)
                    .frame(height: 28)
            }.padding(.horizontal, 16).frame(height: 46)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.08)))
            if enteringPlatform {
                Button("Continue") { confirmCustomPlatform() }.buttonStyle(SetupButtonStyle(primary: true))
                    .disabled(customPlatform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customPlatform.count > 40)
            }

        }
    }
    private func selectOther(_ item: String) {
        if item == "Other" { enteringPlatform = true; customPlatformFocused = true }
        else { enteringPlatform = false; choose(item) }
    }
    private func confirmCustomPlatform() {
        let platform = customPlatform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !platform.isEmpty, platform.count <= 40 else { return }
        choose(platform)
    }
    private var questionFlow: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 9) {
                SetupPlatformBadge(platform: productPlatform, size: 24)
                Text(platformName).font(.system(size: 15, weight: .semibold))
                Button("Change") { withAnimation { step = 0 } }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ink.opacity(0.5)).padding(.leading, 4)
                Spacer()
            }
            HStack(spacing: 0) {
                statusCapsule("Launched", value: "launched")
                statusCapsule("Not launched", value: "unlaunched")
            }.padding(3).background(ink.opacity(0.045), in: Capsule()).fixedSize()
            if question > 0 {
                Button { goPrevious() } label: { Label("Previous", systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ink.opacity(0.65))
                    .disabled(advancing)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 17) {
                    stepCircle(currentNumber, active: true)
                    VStack(alignment: .leading, spacing: 16) {
                        questionContent.id(question).transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 6)))
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 3)
                }.padding(.bottom, question < 5 ? 30 : 0)
                    .background(alignment: .leading) {
                        if question < 5 {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 30)
                                Rectangle().fill(ink.opacity(0.13)).frame(width: 2)
                                    .overlay(alignment: .top) {
                                        Rectangle().fill(accent).scaleEffect(x: 1, y: connectorFill, anchor: .top)
                                    }
                            }.frame(width: 28)
                        }
                    }
                if question < 5 {
                    HStack(spacing: 17) {
                        stepCircle(currentNumber + 1, active: false)
                        Text(nextQuestionTitle).font(.system(size: 14, weight: .medium)).foregroundStyle(ink.opacity(0.3))
                    }
                }
            }
        }.frame(width: 550).frame(maxWidth: .infinity)
    }
    private var completedStepNavigation: some View {
        HStack(spacing: 0) {
                    ForEach(Array(history.completed(in: questionSequence, route: progressKey).enumerated()), id: \.element) { index, visited in
                        if index > 0 { Capsule().fill(accent.opacity(0.45)).frame(width: 14, height: 2).padding(.horizontal, 5) }
                        Button { question = visited; connectorFill = 0; SetupFeedback.selection() } label: {
                            Text("\((questionSequence.firstIndex(of: visited) ?? visited) + 1)")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(accent.opacity(visited == question ? 1 : 0.72), in: Circle())
                                .overlay(Circle().strokeBorder(accent.opacity(visited == question ? 0.3 : 0), lineWidth: 3).padding(-3))
                        }.buttonStyle(.plain).help("Return to step \((questionSequence.firstIndex(of: visited) ?? visited) + 1)")
                    }
                }.animation(.easeInOut(duration: reduceMotion ? 0 : 0.3), value: history.completed(in: questionSequence, route: progressKey))
            .disabled(advancing)
    }
    private func statusCapsule(_ title: String, value: String) -> some View {
        Button {
            guard launchStatus != value else { return }
            statusProgress[launchStatus] = (question, manualEntry)
            let restored = statusProgress[value] ?? (question: 0, manual: false)
            withAnimation {
                launchStatus = value; question = restored.question; manualEntry = restored.manual
                metadataError = nil; metadataRequestID = UUID(); readingMetadata = false
            }
            SetupFeedback.selection()
        } label: {
            Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 9)
                .background(launchStatus == value ? Color.white : .clear, in: Capsule())
                .shadow(color: .black.opacity(launchStatus == value ? 0.08 : 0), radius: 3, y: 1)
        }.buttonStyle(.plain)
    }
    private func stepCircle(_ number: Int, active: Bool) -> some View {
        Text("\(number)").font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? .white : ink.opacity(0.3)).frame(width: 28, height: 28)
            .background(active ? accent : ink.opacity(0.06), in: Circle())
            .padding(3).background(active ? accent.opacity(0.15) : .clear, in: Circle()).padding(-3)
    }
    @ViewBuilder private var questionContent: some View {
        if question == 0 && usesLink {
            VStack(alignment: .leading, spacing: 5) {
                Text("Add your app’s public link").font(.system(size: 16, weight: .semibold))
                Text("We’ll read the details and build its profile.").font(.system(size: 13)).foregroundStyle(ink.opacity(0.5))
            }
            entry("Website, App Store or Google Play link", text: $website)
            if let metadataError { Text(metadataError).font(.system(size: 12)).foregroundStyle(.red) }
            HStack(spacing: 18) {
                Button { readMetadata() } label: { if readingMetadata { HStack { ProgressView().controlSize(.small); Text("Reading your app…") } } else { Text("Read my app") } }
                    .buttonStyle(SetupButtonStyle(primary: true)).disabled(website.isEmpty || readingMetadata)
                Button("Describe instead") { metadataRequestID = UUID(); readingMetadata = false; manualEntry = true; question = manualQuestion }
                    .buttonStyle(SetupButtonStyle(primary: false))
            }
        } else if question == 0 {
            Text("What’s your app called?").font(.system(size: 16, weight: .semibold))
            entry("App name", text: $name)
            nextButton(disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || name.count > 70)
        } else if question == 1 {
            VStack(alignment: .leading, spacing: 5) {
                Text("What does \(name.isEmpty ? "your app" : name) help people do?").font(.system(size: 16, weight: .semibold))
                Text("What does it analyse, create or change for someone? Include the result they get.").font(.system(size: 13)).foregroundStyle(ink.opacity(0.5))
            }
            entry("What it does and the problem it solves", text: $description, multiline: true)
            Text("\(description.count)/1200").font(.system(size: 11)).foregroundStyle(ink.opacity(0.4))
            nextButton(disabled: description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 || description.count > 1200)
        } else if question == 2 {
            VStack(alignment: .leading, spacing: 5) {
                Text("Who is it for?").font(.system(size: 16, weight: .semibold))
                Text("Everyone is a valid answer. A use case helps us focus.").font(.system(size: 13)).foregroundStyle(ink.opacity(0.5))
            }
            entry("Everyone, or a particular group", text: $audience)
            nextButton(disabled: audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || audience.count > 240)
        } else if question == 3 {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("Which keywords describe your app?").font(.system(size: 16, weight: .semibold))
                    Button { showingKeywordHelp = true } label: {
                        Image(systemName: "questionmark.circle").font(.system(size: 14)).foregroundStyle(ink.opacity(0.55)).padding(3).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Help with research keywords")
                        .onHover { showingKeywordHelp = $0 }
                        .popover(isPresented: $showingKeywordHelp, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Make your research more relevant").font(AppFont.ui(14, weight: .semibold))
                                Text("Add words or short phrases about your app, its audience or the problem it solves. Use singular terms and separate them with commas (English or Chinese).")
                                Text("Required · 100 characters maximum, including commas.").foregroundStyle(Palette.secondary)
                            }.font(AppFont.ui(13)).lineSpacing(4).padding(18).frame(width: 310).background(Palette.background).preferredColorScheme(.light)
                        }

                }
                Text("These help us explore more of your niche and refine your results.").font(.system(size: 13)).foregroundStyle(ink.opacity(0.5))
            }.zIndex(20)
            entry("e.g. productivity, design, collaboration", text: $keywords)
            Text("\(keywords.count)/100 characters · required").font(.system(size: 11)).foregroundStyle(keywords.count > 100 ? .red : ink.opacity(0.5))
            nextButton(disabled: !ResearchKeywords.valid(keywords))
        } else if question == 4 {
            Text("Any competitors we should know?").font(.system(size: 16, weight: .semibold))
            entry("Names or links, one per line", text: $competitors, multiline: true)
            nextButton(disabled: false, optional: true)
        } else {
            Text(name).font(.system(size: 17, weight: .semibold))
            if !category.isEmpty { Text(category).font(.system(size: 12)).foregroundStyle(accent) }
            Text("Audience: \(audience)").font(.system(size: 12)).foregroundStyle(ink.opacity(0.6))
            Text(description).font(.system(size: 13)).foregroundStyle(ink.opacity(0.65)).lineSpacing(4).lineLimit(5)
            HStack(spacing: 17) {
                Button(existingProject == nil ? "Create Project" : "Save Changes") { saveProject() }.buttonStyle(SetupButtonStyle(primary: true)).disabled(!validDetails)
                Button("Refine profile") { manualEntry = true; question = 0 }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ink.opacity(0.5))
            }
        }
    }
    private func entry(_ placeholder: String, text: Binding<String>, multiline: Bool = false) -> some View {
        Group {
            if multiline { TextField(placeholder, text: text, axis: .vertical).lineLimit(3...4)
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) { return .ignored }
                        submitQuestion(); return .handled
                    } }
            else { TextField(placeholder, text: text).lineLimit(1) }
        }.textFieldStyle(.plain).font(.system(size: 14)).padding(13)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.1)))
            .accessibilityLabel(placeholder)
            .onSubmit { submitQuestion() }
    }
    private func nextButton(disabled: Bool, optional: Bool = false) -> some View {
        HStack(spacing: 18) {
            Button("Continue") { advanceQuestion() }.buttonStyle(SetupButtonStyle(primary: true)).disabled(disabled || advancing)
            if optional { Button("Skip") { advanceQuestion() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ink.opacity(0.5)) }
            if launchStatus == "launched" && manualEntry {
                Button("Use a link instead") {
                    manualQuestion = question; manualEntry = false; question = 0; metadataError = nil
                }.buttonStyle(SetupButtonStyle(primary: false)).disabled(advancing)
            }

        }
    }
    private func submitQuestion() {
        guard step == 1, !advancing, !readingMetadata else { return }
        if question == 0 && usesLink {
            guard !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            readMetadata()
        } else if question == 5 { saveProject() }
        else {
            if question == 0 && (name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || name.count > 70) { return }
            if question == 1 && (description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 || description.count > 1200) { return }
            if question == 3 && !ResearchKeywords.valid(keywords) { return }
            if question == 2 && (audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || audience.count > 240) { return }
            advanceQuestion()
        }
    }
    private func advanceQuestion() {
        guard !advancing else { return }
        advancing = true
        let route = progressKey
        let finished = question
        withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.62)) { connectorFill = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 660))
            history.complete(finished, route: route)
            question = questionSequence.first(where: { $0 > finished }) ?? 5
            connectorFill = 0
            advancing = false
            SetupFeedback.selection()
        }
    }
    private func readMetadata() {
        readingMetadata = true; metadataError = nil
        let sourceURL = normalizedWebsite
        let requestID = UUID(); metadataRequestID = requestID
        Task {
            defer { if metadataRequestID == requestID { readingMetadata = false } }
            do {
                let details = try await ResearchClient().metadata(sourceURL)
                guard normalizedWebsite == sourceURL, metadataRequestID == requestID else { return }
                description = details.researchDescription
                iconURL = details.icon
                iconData = details.icon == nil ? nil : try? await ProjectIconAsset.download(details.icon!)
                guard normalizedWebsite == sourceURL, metadataRequestID == requestID else { return }
                if name.isEmpty { name = String(details.title.prefix(70)) }
                category = details.details?.categories?.joined(separator: ", ") ?? ""
                if name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
                    manualEntry = true
                    question = name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? 0 : 1
                } else {
                    metadataRead = true
                    history.complete(0, route: progressKey)
                    question = 2
                }
                SetupFeedback.selection()
            } catch { if metadataRequestID == requestID { metadataError = error.localizedDescription } }
        }
    }
    private func closeForm() {
        if let onClose { ProjectWindowMorph.collapse(completion: onClose) } else { dismiss() }
    }
    private func saveProject() {
        guard validDetails, !readingMetadata else { return }
        if existingProject == nil { ProjectWindowMorph.prepareWorkspace() }
        if let project = existingProject {
            store.updateBrief(id: project.id, name: name, description: description, audience: audience, website: normalizedWebsite, color: color, platform: productPlatform, status: launchStatus, keywords: ResearchKeywords.parse(keywords), competitors: CompetitorNames.parse(competitors), iconURL: iconURL, iconData: iconData)
        } else {
            store.addProject(name: name, description: description, audience: audience, website: normalizedWebsite, color: color, platform: productPlatform, status: launchStatus, keywords: ResearchKeywords.parse(keywords), competitors: CompetitorNames.parse(competitors), iconURL: iconURL, iconData: iconData)
        }
        SetupFeedback.complete()
        if let onClose { onClose() } else { dismiss() }
    }
}

private struct SetupField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(hex: 0x514D45))
            Group {
                if multiline { TextField(placeholder, text: $text, axis: .vertical).lineLimit(3...5) }
                else { TextField(placeholder, text: $text).lineLimit(1) }
            }.textFieldStyle(.plain).font(.system(size: 15)).focused($focused)
                .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(focused ? Color(hex: 0x7563AD) : Color.black.opacity(0.10)))
                .animation(.easeOut(duration: 0.18), value: focused)
        }
    }
}
private struct SetupButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Color(hex: 0x39362E))
            .padding(.horizontal, 20).frame(height: 40)
            .background(primary ? Color(hex: 0x34362E) : Color.black.opacity(0.04), in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct OSLogo: View {
    let platform: String
    var body: some View {
        Group {
            if platform == "iOS" || platform == "Mac" { Image(systemName: "apple.logo").resizable().scaledToFit() }
            else if platform == "Web" { Image(systemName: "globe").resizable().scaledToFit() }
            else if platform == "Linux" { Image("OSLinux").resizable().scaledToFit() }
            else if ["Android", "Windows", "HarmonyOS"].contains(platform) { Image("OS" + platform).renderingMode(.template).resizable().scaledToFit() }
            else { Image(systemName: "square.grid.2x2").resizable().scaledToFit() }
        }.accessibilityLabel(platform)
    }
}
struct SetupPlatformBadge: View {
    let platform: String
    var size: CGFloat
    private var background: Color {
        switch platform {
        case "iOS": Color(hex: 0x202124)
        case "Android": Color(hex: 0x15352D)
        case "Web": Color(hex: 0x4A7BE8)
        case "Mac": Color(hex: 0x202124)
        case "Windows": Color(hex: 0x0078D4)
        case "Linux": Color(hex: 0xFFF2BF)
        case "HarmonyOS": Color(hex: 0x0A59F7)
        default: Color(hex: 0x7964CF)
        }
    }
    var body: some View {
        OSLogo(platform: platform).foregroundStyle(platform == "Android" ? Color(hex: 0x3DDC84) : .white)
            .frame(width: size * 0.62, height: size * 0.62)
            .frame(width: size, height: size)
            .background(background.gradient, in: RoundedRectangle(cornerRadius: size * 0.23))
            .overlay(RoundedRectangle(cornerRadius: size * 0.23).strokeBorder(.white.opacity(0.65), lineWidth: 0))
            .shadow(color: .black.opacity(["iOS", "Mac"].contains(platform) ? 0.08 : 0), radius: 3, y: 2)
    }
}
/// The dropdown and custom OS entry share one field and one native menu.
private struct OtherPlatformSelector: NSViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool
    var select: (String) -> Void
    var submit: () -> Void
    final class Field: NSView, NSTextFieldDelegate {
        final class Input: NSTextField {
            var open: (() -> Void)?
            override func mouseDown(with event: NSEvent) {
                if isEditable { super.mouseDown(with: event) } else { open?() }
            }
        }
        let input = Input()
        let arrow = NSButton()
        var parent: OtherPlatformSelector?
        override init(frame: NSRect) {
            super.init(frame: frame)
            input.isBordered = false; input.drawsBackground = false
            input.font = .systemFont(ofSize: 14); input.delegate = self
            input.placeholderString = "Choose another platform"
            input.open = { [weak self] in self?.openMenu() }
            input.setAccessibilityLabel("Operating system")
            arrow.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Choose another platform")
            arrow.isBordered = false; arrow.target = self; arrow.action = #selector(openMenu)
            addSubview(input); addSubview(arrow)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layout() {
            super.layout()
            input.frame = NSRect(x: 0, y: (bounds.height - 22) / 2, width: bounds.width - 38, height: 22)
            arrow.frame = NSRect(x: bounds.width - 28, y: 0, width: 28, height: bounds.height)
        }
        override func mouseDown(with event: NSEvent) { openMenu() }
        @objc func openMenu() {
            let menu = NSMenu(); menu.font = .systemFont(ofSize: 14); menu.minimumWidth = 260
            for name in ["tvOS", "watchOS", "visionOS", "ChromeOS", "Other"] {
                let item = NSMenuItem(title: name, action: #selector(pick(_:)), keyEquivalent: "")
                item.target = self; menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: self)
        }
        @objc func pick(_ item: NSMenuItem) {
            guard let parent else { return }
            if item.title == "Other" {
                parent.editing = true; input.isEditable = true; input.isSelectable = true
                input.stringValue = parent.text; input.placeholderString = "Operating system name"
                window?.makeFirstResponder(input)
            } else { parent.editing = false; parent.select(item.title) }
        }
        func controlTextDidChange(_ notification: Notification) { parent?.text = input.stringValue }
        func controlTextDidEndEditing(_ notification: Notification) {
            parent?.text = input.stringValue
            if (notification.userInfo?["NSTextMovement"] as? Int) == NSReturnTextMovement { parent?.submit() }
        }
    }
    func makeNSView(context: Context) -> Field { Field() }
    func updateNSView(_ field: Field, context: Context) {
        field.parent = self
        field.input.isEditable = editing; field.input.isSelectable = editing
        field.input.placeholderString = editing ? "Operating system name" : "Choose another platform"
        field.input.textColor = .labelColor
        if field.input.currentEditor() == nil { field.input.stringValue = editing ? text : "" }
    }
}

private struct PlatformTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum SetupFeedback {
    private static var completionSound: NSSound?
    static func selection() {
        guard UserDefaults.standard.object(forKey: "setupHaptics") as? Bool ?? true else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    static func complete() {
        selection()
        if UserDefaults.standard.object(forKey: "setupSound") as? Bool ?? true { completionSound = NSSound(contentsOfFile: Bundle.main.path(forResource: "WorkspaceReady", ofType: "wav") ?? "", byReference: false); completionSound?.play() }
    }
}

struct ImportReferenceForm: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var url = ""
    @State private var note = ""
    @State private var platform: Platform = .web
    private var validURL: Bool {
        if url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        guard let value = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = value.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && value.host != nil
    }
    var body: some View {
        SheetFrame(title: "Keep a useful reference.", subtitle: "Add a link and your own notes. This saves locally; it doesn't fetch or analyze the source.") {
            FormInput(label: "Title", placeholder: "What caught your attention?", text: $title)
            FormInput(label: "Source link · optional", placeholder: "https://", text: $url)
            if !validURL { Text("Use a complete http or https link.").font(AppFont.ui(11)).foregroundStyle(.orange) }
            Picker("Platform", selection: $platform) {
                ForEach(Platform.allCases) { Text($0.rawValue).tag($0) }
            }.font(AppFont.ui(12))
            FormInput(label: "Your notes", placeholder: "Paste the relevant text or describe what makes this useful.", text: $note, multiline: true)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(AppButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save reference") {
                    store.importReference(title: title, url: url.trimmingCharacters(in: .whitespacesAndNewlines), note: note, platform: platform)
                    dismiss()
                }.buttonStyle(AppButtonStyle(primary: true)).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validURL)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct NewDraftForm: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var format: DraftFormat = .xPost
    var body: some View {
        SheetFrame(title: "What do you want to make?", subtitle: "Start with a blank draft. No generation credits needed.") {
            FormInput(label: "Draft title", placeholder: "An idea worth sharing", text: $title)
            VStack(spacing: 8) {
                ForEach(DraftFormat.allCases) { value in
                    Button { format = value } label: {
                        HStack(spacing: 12) {
                            Image(systemName: value.symbol).frame(width: 20)
                            Text(value.rawValue)
                            Spacer()
                            if value == .image || value == .video {
                                Text(value == .image ? "Editable layout" : "Brief only").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                            }
                            Image(systemName: format == value ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(format == value ? Palette.mint : Palette.muted)
                        }.font(AppFont.ui(12)).padding(13).background(Palette.surface, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(format == value ? Palette.mint.opacity(0.5) : Palette.border))
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(AppButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create draft") {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let id = store.createDraft(title: trimmedTitle.isEmpty ? "Untitled draft" : trimmedTitle, format: format)
                    store.selectedReference = nil
                    store.page = .studio
                    dismiss()
                    store.editingDraftID = id
                }.buttonStyle(AppButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct BrandColorPicker: View {
    @Binding var selection: BrandColor
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project accent").font(AppFont.ui(11, weight: .medium)).foregroundStyle(Palette.secondary)
            HStack(spacing: 12) {
                ForEach(BrandColor.allCases) { value in
                    Button { selection = value } label: {
                        Circle().fill(value.color).frame(width: 26, height: 26)
                            .overlay {
                                if value == selection {
                                    Image(systemName: "checkmark").font(AppFont.ui(11, weight: .bold)).foregroundStyle(Palette.background)
                                }
                            }
                    }.buttonStyle(.plain).help(value.rawValue).accessibilityLabel(value.rawValue)
                }
                Text(selection.rawValue).font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
            }
        }
    }
}

struct WorkspaceSettings: View {
    var onClose: (() -> Void)? = nil
    @AppStorage("setupSound") private var setupSound = true
    @AppStorage("setupHaptics") private var setupHaptics = true
    @State private var section = "General"
    private let sections = [("General", "slider.horizontal.3"), ("Research", "sparkle.magnifyingglass"), ("About & Support", "info.circle")]
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let onClose {
                    Button(action: onClose) { Label("Back to project", systemImage: "chevron.left") }
                        .buttonStyle(.plain).font(AppFont.ui(12)).foregroundStyle(Palette.secondary).padding(.bottom, 12)
                }
                Text("Settings").font(AppFont.ui(21, weight: .semibold)).padding(.bottom, 24)
                ForEach(sections, id: \.0) { item in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { section = item.0 } } label: {
                        Label(item.0, systemImage: item.1).font(AppFont.ui(13, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(11)
                            .background(section == item.0 ? Color.black.opacity(0.065) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(22).frame(width: 254).background(Color(hex: 0xEDEAE5))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(section).font(AppFont.ui(25, weight: .semibold))
                    if section == "General" {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Project opening sound")
                                Spacer()
                                Toggle("Project opening sound", isOn: $setupSound).labelsHidden()
                            }
                            Divider()
                            HStack {
                                Text("Trackpad feedback")
                                Spacer()
                                Toggle("Trackpad feedback", isOn: $setupHaptics).labelsHidden()
                            }
                        }.toggleStyle(.switch).tint(Color(hex: 0x645675))
                            .padding(22).background(.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))
                        Text("Feedback follows your Mac’s sound and accessibility settings.")
                            .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                    } else if section == "Research" {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Research is specific to each project.").font(AppFont.ui(15, weight: .medium))
                            Text("Open About → Research in your project to edit keywords and competitors. Follow accounts and topics from the Sources section.")
                                .font(AppFont.ui(13)).foregroundStyle(Palette.secondary).lineSpacing(5)
                        }.padding(22).background(.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))
                    } else { AppInformationView() }
                    Spacer(minLength: 20)
                }.padding(32).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Palette.background)
        }.foregroundStyle(Palette.text).preferredColorScheme(.light).frame(minWidth: 700, minHeight: 460)
    }
}

struct AppInformationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outloud").font(AppFont.ui(23, weight: .semibold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
            Divider()
            Link("Contact support", destination: URL(string: "mailto:support@tryoutloud.xyz")!)
            Link("Send feedback", destination: URL(string: "mailto:support@tryoutloud.xyz?subject=Outloud%20feedback")!)
            #if DEBUG
            Text("Development build · Automatic updates are off.").font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
            #else
            Button("Check for Updates…") { AppUpdater.shared.check() }.buttonStyle(.link)
            #endif
        }.font(AppFont.ui(13))
    }
}

struct FollowingForm: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var platform: Platform = .x
    var body: some View {
        SheetFrame(title: "Keep something in view.", subtitle: "Save a creator, competitor, or topic. Automatic monitoring will follow in a later build.") {
            FormInput(label: "Account or topic", placeholder: "@creator, a product name, or a topic", text: $name)
            Picker("Platform", selection: $platform) {
                ForEach(Platform.allCases) { Text($0.rawValue).tag($0) }
            }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(AppButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add to watchlist") {
                    store.addTarget(name: name.trimmingCharacters(in: .whitespacesAndNewlines), platform: platform)
                    dismiss()
                }.buttonStyle(AppButtonStyle(primary: true)).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
