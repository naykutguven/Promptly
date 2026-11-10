import Foundation
import SwiftUI

/// An isolated engine demonstration, independent of the live prompter and saved preferences.
struct PrompterLineLayoutDemoView: View {
    let text: String

    @Environment(\.fontResolutionContext) private var fontContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: PrompterLineLayoutDemoModel
    @State private var fontSize: CGFloat = 28
    @State private var preferredWidth: CGFloat = 520
    @State private var typeface: Typeface = .system
    @State private var isBold = false
    @State private var visibleLineID: Int?
    @State private var isUserScrolling = false
    @State private var retryGeneration = 0

    init(text: String, initialLayout: PrompterLineLayoutDemoModel.Layout? = nil) {
        self.text = text
        self.model = PrompterLineLayoutDemoModel(initialLayout: initialLayout)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, min(preferredWidth, geometry.size.width - 64))
            let font = Font.system(
                size: fontSize, weight: isBold ? .bold : .regular, design: typeface.design
            ).resolve(in: fontContext)
            let request = PrompterLineLayoutDemoModel.Request(text: text, font: font, width: width)

            VStack(alignment: .leading, spacing: 0) {
                controls
                    .padding()

                Divider()

                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        GeometryReader { viewport in
                            reader(height: viewport.size.height, proxy: proxy)
                        }

                        Divider()

                        navigation(proxy: proxy)
                            .padding()
                    }
                    .onChange(of: model.layout?.request) { _, _ in
                        // Restoring a target after reflow must not round the source anchor backward.
                        if !isUserScrolling {
                            scrollToCurrentLine(using: proxy, animated: false)
                        }
                    }
                }
            }
            .task(id: LayoutTask(
                request: isUserScrolling ? nil : request, retryGeneration: retryGeneration
            )) {
                // Defer reflow until manual scrolling ends so restoration cannot fight the gesture.
                guard !isUserScrolling else { return }
                await model.update(for: request)
            }
        }
        .background(.background)
        .frame(minWidth: 400, minHeight: 420)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line layout demo")
                .font(.title2)

            HStack {
                Picker("Typeface", selection: $typeface) {
                    Text("System").tag(Typeface.system)
                    Text("Serif").tag(Typeface.serif)
                    Text("Monospaced").tag(Typeface.monospaced)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

                Toggle("Bold", isOn: $isBold)
                    .toggleStyle(.checkbox)
            }

            HStack {
                Text("Text size")
                    .frame(width: 100, alignment: .leading)
                Slider(value: $fontSize, in: 16...48, step: 1)
                    .accessibilityLabel("Text size")
                Text("\(fontSize, format: .number.precision(.fractionLength(0))) pt")
                    .monospacedDigit()
                    .frame(minWidth: 52, alignment: .trailing)
            }

            HStack {
                Text("Preferred width")
                    .frame(width: 100, alignment: .leading)
                Slider(value: $preferredWidth, in: 180...720, step: 20)
                    .accessibilityLabel("Preferred reading width")
                Text("\(preferredWidth, format: .number.precision(.fractionLength(0))) pt")
                    .monospacedDigit()
                    .frame(minWidth: 52, alignment: .trailing)
            }

            Text("Scroll or select a line, then change the typeface, text size, or width.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = model.errorMessage {
                HStack {
                    Text(error)
                        .foregroundStyle(.red)
                    Button("Retry") { retryGeneration += 1 }
                }
                .font(.callout)
            }
        }
    }

    private func reader(height: CGFloat, proxy: ScrollViewProxy) -> some View {
        ScrollView(.vertical) {
            if let layout = model.layout {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(layout.lines, id: \.sourceRange.location) { line in
                        Button {
                            model.selectLine(id: line.sourceRange.location)
                            scrollToCurrentLine(using: proxy, animated: true)
                        } label: {
                            Text(verbatim: line.text.isEmpty ? "\u{00A0}" : line.text)
                                .font(Font(layout.request.font.ctFont))
                                .foregroundStyle(
                                    line.sourceRange.location == model.currentLineID
                                        ? Color.primary : Color.secondary
                                )
                                .lineLimit(1)
                                .frame(width: layout.request.width, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(line.text.isEmpty ? Text("Blank line") : Text(verbatim: line.text))
                        .accessibilityAddTraits(
                            line.sourceRange.location == model.currentLineID ? .isSelected : []
                        )
                        .id(line.sourceRange.location)
                    }
                }
                .frame(width: layout.request.width)
                .scrollTargetLayout()
                .padding(.bottom, height)
                .frame(maxWidth: .infinity)
            } else if model.isLoading {
                ProgressView("Laying out text…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ContentUnavailableView("No lines", systemImage: "text.alignleft")
            }
        }
        .scrollPosition(id: $visibleLineID, anchor: .top)
        .onChange(of: visibleLineID) { _, id in
            if isUserScrolling, let id, id != model.currentLineID {
                model.selectLine(id: id)
            }
        }
        .onScrollPhaseChange { _, phase in
            switch phase {
            case .interacting, .decelerating:
                if !isUserScrolling { model.invalidatePendingLayout() }
                isUserScrolling = true
            case .idle:
                if isUserScrolling, let id = visibleLineID, id != model.currentLineID {
                    model.selectLine(id: id)
                }
                isUserScrolling = false
            case .tracking:
                break
            case .animating:
                isUserScrolling = false
            }
        }
    }

    private func navigation(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Previous") {
                    model.move(by: -1)
                    scrollToCurrentLine(using: proxy, animated: true)
                }
                .disabled(model.currentLineIndex == nil || model.currentLineIndex == 0)

                Button("Next") {
                    model.move(by: 1)
                    scrollToCurrentLine(using: proxy, animated: true)
                }
                .disabled(
                    model.currentLineIndex == nil ||
                    model.currentLineIndex == (model.layout?.lines.count ?? 0) - 1
                )

                Spacer()

                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating layout")
                }

                Button("Restart") {
                    if let first = model.layout?.lines.first {
                        model.selectLine(id: first.sourceRange.location)
                        scrollToCurrentLine(using: proxy, animated: true)
                    }
                }
                .disabled(model.layout?.lines.isEmpty != false)
            }

            HStack {
                Text("Line \(model.currentLineIndex.map { $0 + 1 } ?? 0) of \(model.layout?.lines.count ?? 0)")
                Spacer()
                if let width = model.layout?.request.width {
                    Text("\(width, format: .number.precision(.fractionLength(0))) pt column")
                    Spacer()
                }
                Text("Source offset \(model.sourceOffset)")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    private func scrollToCurrentLine(using proxy: ScrollViewProxy, animated: Bool) {
        guard let id = model.currentLineID else { return }
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
        } else {
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private enum Typeface: Hashable {
        case system, serif, monospaced

        var design: Font.Design {
            switch self {
            case .system: .default
            case .serif: .serif
            case .monospaced: .monospaced
            }
        }
    }

    private struct LayoutTask: Equatable {
        let request: PrompterLineLayoutDemoModel.Request?
        let retryGeneration: Int
    }

    fileprivate static let sampleText = """
    Welcome to the line layout demonstration. Each visible row comes from the original script, with a source range that stays meaningful when the text wraps differently.

    Select a line farther down the script. Try a larger font, a different typeface, or a narrower reading column. The highlighted row should continue to contain the same source position.

    You can also scroll manually, use Previous and Next, or return to the beginning with Restart. Highlighting changes only the text color.

    Blank paragraphs stay in the script. Composed characters such as café, é, and 👨‍👩‍👧‍👦 stay together when a line breaks.

    Widen the column and narrow it again without navigating. The stored source offset should stay the same even when the beginning of the highlighted row changes.

    This final paragraph lets you check that the last line can reach the top of the reading area.
    """
}

private struct PreparedDemoPreview: PreviewModifier {
    let isNarrow: Bool

    struct PreparedLayouts {
        let wide: PrompterLineLayoutDemoModel.Layout
        let narrow: PrompterLineLayoutDemoModel.Layout
    }

    static func makeSharedContext() async throws -> PreparedLayouts {
        let font = Font.system(size: 28).resolve(in: EnvironmentValues().fontResolutionContext)
        let wide = PrompterLineLayoutDemoModel.Request(
            text: PrompterLineLayoutDemoView.sampleText, font: font, width: 520
        )
        let narrow = PrompterLineLayoutDemoModel.Request(text: wide.text, font: font, width: 366)
        let engine = PrompterLineLayoutEngine()
        let wideLines = try await engine.layout(text: wide.text, font: font, width: wide.width)
        let narrowLines = try await engine.layout(text: narrow.text, font: font, width: narrow.width)
        return PreparedLayouts(
            wide: .init(request: wide, lines: wideLines),
            narrow: .init(request: narrow, lines: narrowLines)
        )
    }

    func body(content: Content, context: PreparedLayouts) -> some View {
        content.environment(\.preparedDemoLayout, isNarrow ? context.narrow : context.wide)
    }
}

private extension EnvironmentValues {
    @Entry var preparedDemoLayout: PrompterLineLayoutDemoModel.Layout?
}

private struct PreparedDemoContent: View {
    @Environment(\.preparedDemoLayout) private var layout

    var body: some View {
        if let layout {
            PrompterLineLayoutDemoView(text: layout.request.text, initialLayout: layout)
        }
    }
}

#Preview("Line layout engine", traits: .modifier(PreparedDemoPreview(isNarrow: false))) {
    PreparedDemoContent()
        .frame(width: 720, height: 640)
}

#Preview("Narrow reading window", traits: .modifier(PreparedDemoPreview(isNarrow: true))) {
    PreparedDemoContent()
        .frame(width: 430, height: 640)
}
