//
//  TranslationProgressView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI

/// Progress panel for the active or most recent translation run.
///
/// `ContentView` computes the metrics so this view can remain a pure rendering
/// component. It shows a linear progress bar, compact run metrics, and a Stop button
/// while translation is active.
struct TranslationProgressView: View {
    /// Human-readable workflow state, such as `Idle` or the active target language.
    let status: String
    /// Normalized progress value between `0` and `1`.
    let progressValue: Double
    /// Completed source-string/target-language units.
    let completedUnits: Int
    /// Total planned source-string/target-language units.
    let totalUnits: Int
    /// Completed strings for the active target language.
    let translatedStrings: Int
    /// Strings planned for the active target language.
    let stringsToTranslate: Int
    /// Completed target languages in the run.
    let completedLanguages: Int
    /// Total target languages in the run.
    let totalLanguages: Int
    /// Formatted elapsed time.
    let elapsedTime: String
    /// Formatted ETA or terminal state text.
    let estimatedTimeRemaining: String
    /// Whether a translation session is active.
    let isTranslating: Bool
    /// Whether the last run completed successfully.
    let didFinishTranslation: Bool
    /// Cancels the active translation run.
    let cancelTranslation: () -> Void

    /// Compact percentage text shown beside the progress bar.
    private var progressText: String {
        guard totalUnits > 0 else {
            return "Ready"
        }

        return "\(Int((progressValue * 100).rounded()))%"
    }

    /// Active-language string count text.
    private var stringsText: String {
        guard stringsToTranslate > 0 else {
            return "No file"
        }

        return "\(translatedStrings)/\(stringsToTranslate)"
    }

    /// Target-language count text.
    private var languagesText: String {
        guard totalLanguages > 0 else {
            return "No target"
        }

        return "\(completedLanguages)/\(totalLanguages)"
    }

    /// Total unit count text.
    private var totalText: String {
        guard totalUnits > 0 else {
            return "No work"
        }

        return "\(completedUnits)/\(totalUnits)"
    }

    /// Color that communicates idle, active, and complete states.
    private var progressTint: Color {
        if didFinishTranslation {
            return .green
        }

        return isTranslating ? .accentColor : .secondary
    }

    /// Fixed metric grid definition.
    ///
    /// The minimum column width keeps the metric labels legible on smaller windows
    /// without allowing dynamic values to resize the whole panel.
    private var metricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 110), spacing: 10),
            count: 5
        )
    }

    /// Builds the progress panel.
    ///
    /// Accessibility:
    /// The progress bar exposes a synthesized value that includes percentage, unit
    /// count, and ETA so assistive technologies receive the same context sighted users
    /// get from the panel.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressHeader

            ProgressView(value: progressValue, total: 1)
                .progressViewStyle(.linear)
                .tint(progressTint)
                .accessibilityLabel("Translation progress")
                .accessibilityValue(progressAccessibilityValue)
                .accessibilityHint("Shows how much of the current translation run is complete.")
                .accessibilityIdentifier("translationProgress")

            metricsGrid
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                SiriProgressGlowView(isActive: isTranslating)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Translation progress section")
    }

    /// Header containing title, status, optional Stop action, and percentage.
    private var progressHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress")
                    .font(.headline)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isTranslating {
                Button("Stop", systemImage: "stop.fill", role: .cancel) {
                    cancelTranslation()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Stop translation")
                .accessibilityHint("Cancels the current translation run.")
                .accessibilityIdentifier("stopTranslationButton")
            }

            Text(progressText)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(progressTint)
                .accessibilityLabel("Progress percentage")
                .accessibilityValue(progressText)
        }
    }

    /// Grid of compact run metrics.
    private var metricsGrid: some View {
        LazyVGrid(
            columns: metricColumns,
            spacing: 10
        ) {
            ProgressMetricView(
                title: "Strings",
                value: stringsText,
                systemImage: "text.quote"
            )

            ProgressMetricView(
                title: "Languages",
                value: languagesText,
                systemImage: "globe"
            )

            ProgressMetricView(
                title: "Total",
                value: totalText,
                systemImage: "checkmark.circle"
            )

            ProgressMetricView(
                title: "Elapsed",
                value: elapsedTime,
                systemImage: "timer"
            )

            ProgressMetricView(
                title: "ETA",
                value: estimatedTimeRemaining,
                systemImage: "clock"
            )
        }
        .frame(maxWidth: .infinity)
    }

    /// VoiceOver value for the progress bar.
    private var progressAccessibilityValue: String {
        "\(progressText), \(completedUnits) of \(totalUnits) units complete. ETA \(estimatedTimeRemaining)."
    }
}

/// Decorative animated border used to indicate active translation.
///
/// The glow is accessibility-hidden because it conveys state already represented by
/// text, progress, and the Stop button.
struct SiriProgressGlowView: View {
    /// Whether the active animation should use the stronger glow state.
    let isActive: Bool

    /// Rotation animation toggle for the angular gradient.
    @State private var rotateGlow = false
    /// Pulse animation toggle for the border scale.
    @State private var pulseGlow = false

    /// Opacity for idle and active states.
    private var glowOpacity: Double {
        isActive ? 0.9 : 0.28
    }

    /// Scale used by the active pulse animation.
    private var glowScale: CGFloat {
        if !isActive {
            return 1
        }

        return pulseGlow ? 1.035 : 0.98
    }

    /// Builds the animated glow.
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .cyan,
                        .blue,
                        .purple,
                        .pink,
                        .orange,
                        .cyan
                    ]),
                    center: .center,
                    angle: rotateGlow ? .degrees(360) : .zero
                ),
                lineWidth: isActive ? 3 : 1.5
            )
            .scaleEffect(glowScale)
            .blur(radius: isActive ? 12 : 8)
            .opacity(glowOpacity)
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    rotateGlow = true
                }

                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Single compact metric in the progress panel.
struct ProgressMetricView: View {
    /// Metric title, kept as `LocalizedStringKey` for SwiftUI localization extraction.
    let title: LocalizedStringKey
    /// Metric value rendered with monospaced digits.
    let value: String
    /// SF Symbol name displayed beside the metric.
    let systemImage: String

    /// Builds the metric row.
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}
