//
//  TranslationProgressView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI

struct TranslationProgressView: View {
    let status: String
    let progressValue: Double
    let completedUnits: Int
    let totalUnits: Int
    let translatedStrings: Int
    let stringsToTranslate: Int
    let completedLanguages: Int
    let totalLanguages: Int
    let elapsedTime: String
    let estimatedTimeRemaining: String
    let isTranslating: Bool
    let didFinishTranslation: Bool
    let cancelTranslation: () -> Void

    private var progressText: String {
        guard totalUnits > 0 else {
            return "Ready"
        }

        return "\(Int((progressValue * 100).rounded()))%"
    }

    private var stringsText: String {
        guard stringsToTranslate > 0 else {
            return "No file"
        }

        return "\(translatedStrings)/\(stringsToTranslate)"
    }

    private var languagesText: String {
        guard totalLanguages > 0 else {
            return "No target"
        }

        return "\(completedLanguages)/\(totalLanguages)"
    }

    private var totalText: String {
        guard totalUnits > 0 else {
            return "No work"
        }

        return "\(completedUnits)/\(totalUnits)"
    }

    private var progressTint: Color {
        if didFinishTranslation {
            return .green
        }

        return isTranslating ? .accentColor : .secondary
    }

    private var metricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 110), spacing: 10),
            count: 5
        )
    }

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

    private var progressAccessibilityValue: String {
        "\(progressText), \(completedUnits) of \(totalUnits) units complete. ETA \(estimatedTimeRemaining)."
    }
}

struct SiriProgressGlowView: View {
    let isActive: Bool

    @State private var rotateGlow = false
    @State private var pulseGlow = false

    private var glowOpacity: Double {
        isActive ? 0.9 : 0.28
    }

    private var glowScale: CGFloat {
        if !isActive {
            return 1
        }

        return pulseGlow ? 1.035 : 0.98
    }

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

struct ProgressMetricView: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

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
