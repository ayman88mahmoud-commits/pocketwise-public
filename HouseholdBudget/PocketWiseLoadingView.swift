import SwiftUI

struct PocketWiseLoadingView: View {

    private let stageMessages = [
        "Preparing your PocketWise hub",
        "Organizing budgets",
        "Checking bills",
        "Syncing wallets & cards",
        "Securing your data",
        "Ready"
    ]

    @State private var isAnimating = false
    @State private var stageIndex = 0

    var body: some View {
        ZStack {
            PocketWiseLoadingBackground(isAnimating: isAnimating)

            ParticleField(isAnimating: isAnimating)

            VStack(spacing: 28) {
                Spacer(minLength: 48)

                ZStack {
                    GlowRing(isAnimating: isAnimating)
                        .frame(width: 240, height: 240)

                    ForEach(financeChips) { chip in
                        FloatingFinanceChip(
                            title: chip.title,
                            systemImage: chip.systemImage,
                            isAnimating: isAnimating,
                            delay: chip.delay
                        )
                        .offset(
                            x: isAnimating ? chip.endOffset.width : chip.startOffset.width,
                            y: isAnimating ? chip.endOffset.height : chip.startOffset.height
                        )
                    }

                    PocketWiseHub()
                }
                .frame(width: 340, height: 340)

                VStack(spacing: 12) {
                    Text("PocketWise")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.pocketWiseGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.pocketWiseGold.opacity(0.35), radius: 16, x: 0, y: 8)

                    LoadingStageText(text: stageMessages[stageIndex])

                    ProgressLine(progress: progress)
                        .frame(width: 210)
                        .padding(.top, 2)
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }

    private var progress: Double {
        guard stageMessages.count > 1 else {
            return 1
        }

        return Double(stageIndex + 1) / Double(stageMessages.count)
    }

    private var financeChips: [FinanceChip] {
        [
            FinanceChip(title: "Bank", systemImage: "building.columns.fill", startOffset: CGSize(width: -124, height: -106), endOffset: CGSize(width: -136, height: -116), delay: 0.05),
            FinanceChip(title: "Wallet", systemImage: "wallet.pass.fill", startOffset: CGSize(width: 118, height: -104), endOffset: CGSize(width: 130, height: -116), delay: 0.15),
            FinanceChip(title: "Card", systemImage: "creditcard.fill", startOffset: CGSize(width: -130, height: 46), endOffset: CGSize(width: -142, height: 58), delay: 0.25),
            FinanceChip(title: "Bill", systemImage: "doc.text.fill", startOffset: CGSize(width: 132, height: 48), endOffset: CGSize(width: 144, height: 58), delay: 0.35),
            FinanceChip(title: "Budget", systemImage: "chart.bar.fill", startOffset: CGSize(width: -74, height: 136), endOffset: CGSize(width: -88, height: 148), delay: 0.45),
            FinanceChip(title: "Calendar", systemImage: "calendar", startOffset: CGSize(width: 82, height: 136), endOffset: CGSize(width: 94, height: 148), delay: 0.55),
            FinanceChip(title: "Valu", systemImage: "checkmark.seal.fill", startOffset: CGSize(width: -6, height: -154), endOffset: CGSize(width: 4, height: -168), delay: 0.65),
            FinanceChip(title: "InstaPay", systemImage: "bolt.fill", startOffset: CGSize(width: 6, height: 164), endOffset: CGSize(width: -6, height: 178), delay: 0.75)
        ]
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            isAnimating = true
        }

        Task {
            for index in stageMessages.indices.dropFirst() {
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        stageIndex = index
                    }
                }
            }
        }
    }
}

private struct PocketWiseLoadingBackground: View {

    let isAnimating: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.05, blue: 0.12),
                    Color(red: 0.02, green: 0.14, blue: 0.18),
                    Color(red: 0.00, green: 0.03, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.pocketWiseTeal.opacity(0.34), .clear],
                center: .center,
                startRadius: 20,
                endRadius: isAnimating ? 280 : 210
            )
            .blur(radius: 10)

            RadialGradient(
                colors: [Color.pocketWiseGold.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: isAnimating ? 360 : 260
            )
            .blur(radius: 18)
        }
    }
}

private struct PocketWiseHub: View {

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .frame(width: 154, height: 118)
                .offset(y: 36)
                .shadow(color: Color.pocketWiseTeal.opacity(0.7), radius: 24, x: 0, y: 12)

            Image(systemName: "house.fill")
                .font(.system(size: 122, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pocketWiseGold, .white.opacity(0.92)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .shadow(color: Color.pocketWiseGold.opacity(0.35), radius: 12, x: 0, y: 6)
                .offset(y: -12)

            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 94, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pocketWiseTeal, Color(red: 0.02, green: 0.33, blue: 0.31)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
                .offset(y: 46)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.pocketWiseGold)
                .padding(12)
                .background(.black.opacity(0.22), in: Circle())
                .overlay(Circle().stroke(Color.pocketWiseTeal.opacity(0.45), lineWidth: 1))
                .offset(y: 120)
        }
    }
}

private struct FloatingFinanceChip: View {

    let title: String
    let systemImage: String
    let isAnimating: Bool
    let delay: Double

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.pocketWiseGold)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.pocketWiseTeal.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: Color.pocketWiseTeal.opacity(0.35), radius: isAnimating ? 14 : 7, x: 0, y: 6)
        .scaleEffect(isAnimating ? 1.04 : 0.96)
        .opacity(isAnimating ? 1 : 0.72)
        .rotationEffect(.degrees(isAnimating ? 1.8 : -1.8))
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(delay), value: isAnimating)
    }
}

private struct LoadingStageText: View {

    let text: String

    var body: some View {
        Text(text)
            .id(text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.74))
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.24), value: text)
    }
}

private struct GlowRing: View {

    let isAnimating: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 16)

            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? Color.pocketWiseGold : Color.pocketWiseTeal)
                    .frame(width: 8, height: 22)
                    .offset(y: -112)
                    .rotationEffect(.degrees(Double(index) * 20))
                    .opacity(isAnimating ? 0.9 : 0.42)
                    .blur(radius: isAnimating && index.isMultiple(of: 3) ? 0.2 : 0)
            }

            Circle()
                .trim(from: 0.08, to: 0.82)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color.pocketWiseTeal, Color.pocketWiseGold, .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .shadow(color: Color.pocketWiseTeal.opacity(0.8), radius: 18, x: 0, y: 0)

            OrbitingDot(isAnimating: isAnimating, size: 9, radius: 116, duration: 2.8, delay: 0)
            OrbitingDot(isAnimating: isAnimating, size: 7, radius: 96, duration: 3.4, delay: 0.4)
        }
        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isAnimating)
    }
}

private struct OrbitingDot: View {

    let isAnimating: Bool
    let size: CGFloat
    let radius: CGFloat
    let duration: Double
    let delay: Double

    var body: some View {
        Circle()
            .fill(Color.pocketWiseGold)
            .frame(width: size, height: size)
            .shadow(color: Color.pocketWiseGold.opacity(0.9), radius: 10, x: 0, y: 0)
            .offset(y: -radius)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: duration).repeatForever(autoreverses: false).delay(delay), value: isAnimating)
    }
}

private struct ParticleField: View {

    let isAnimating: Bool

    var body: some View {
        GeometryReader { proxy in
            ForEach(Particle.seedParticles(in: proxy.size)) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: particle.blur)
                    .opacity(isAnimating ? particle.activeOpacity : particle.restingOpacity)
                    .position(
                        x: isAnimating ? particle.endPoint.x : particle.startPoint.x,
                        y: isAnimating ? particle.endPoint.y : particle.startPoint.y
                    )
                    .animation(.easeInOut(duration: particle.duration).repeatForever(autoreverses: true).delay(particle.delay), value: isAnimating)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProgressLine: View {

    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.09))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.pocketWiseTeal, Color.pocketWiseGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * progress)
                    .shadow(color: Color.pocketWiseTeal.opacity(0.55), radius: 8, x: 0, y: 0)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.28), value: progress)
    }
}

private struct FinanceChip: Identifiable {
    let title: String
    let systemImage: String
    let startOffset: CGSize
    let endOffset: CGSize
    let delay: Double

    var id: String {
        title
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let startPoint: CGPoint
    let endPoint: CGPoint
    let size: CGFloat
    let blur: CGFloat
    let restingOpacity: Double
    let activeOpacity: Double
    let duration: Double
    let delay: Double
    let color: Color

    static func seedParticles(in size: CGSize) -> [Particle] {
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        return [
            Particle(startPoint: CGPoint(x: width * 0.12, y: height * 0.22), endPoint: CGPoint(x: width * 0.16, y: height * 0.18), size: 4, blur: 0.2, restingOpacity: 0.35, activeOpacity: 0.9, duration: 2.3, delay: 0.1, color: Color.pocketWiseTeal),
            Particle(startPoint: CGPoint(x: width * 0.82, y: height * 0.18), endPoint: CGPoint(x: width * 0.78, y: height * 0.23), size: 5, blur: 0.3, restingOpacity: 0.3, activeOpacity: 0.85, duration: 2.8, delay: 0.4, color: Color.pocketWiseGold),
            Particle(startPoint: CGPoint(x: width * 0.22, y: height * 0.72), endPoint: CGPoint(x: width * 0.18, y: height * 0.66), size: 3, blur: 0.2, restingOpacity: 0.25, activeOpacity: 0.75, duration: 3.2, delay: 0.2, color: Color.pocketWiseGold),
            Particle(startPoint: CGPoint(x: width * 0.74, y: height * 0.76), endPoint: CGPoint(x: width * 0.82, y: height * 0.70), size: 4, blur: 0.4, restingOpacity: 0.25, activeOpacity: 0.82, duration: 2.6, delay: 0.6, color: Color.pocketWiseTeal),
            Particle(startPoint: CGPoint(x: width * 0.50, y: height * 0.16), endPoint: CGPoint(x: width * 0.55, y: height * 0.12), size: 3, blur: 0.2, restingOpacity: 0.2, activeOpacity: 0.74, duration: 2.7, delay: 0.8, color: .white.opacity(0.75)),
            Particle(startPoint: CGPoint(x: width * 0.45, y: height * 0.86), endPoint: CGPoint(x: width * 0.52, y: height * 0.82), size: 3, blur: 0.2, restingOpacity: 0.2, activeOpacity: 0.68, duration: 3.5, delay: 1.0, color: Color.pocketWiseGold)
        ]
    }
}

private extension Color {
    static let pocketWiseTeal = Color(red: 0.00, green: 0.82, blue: 0.72)
    static let pocketWiseGold = Color(red: 0.96, green: 0.72, blue: 0.34)
}
