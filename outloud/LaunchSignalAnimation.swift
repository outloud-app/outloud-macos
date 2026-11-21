import AppKit
import SwiftUI

struct FoundingPass: View {
    let number: Int
    private let ink = Color(red: 0.04, green: 0.16, blue: 0.11)
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                OutloudMark(color: ink).frame(width: 13, height: 13)
                Text("FOUNDING PASS").font(AppFont.ui(8, weight: .semibold)).tracking(1.3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "#%03d", number)).font(AppFont.ui(31, weight: .semibold)).tracking(-1.5).monospacedDigit()
                Text("/ 200").font(AppFont.ui(11, weight: .medium)).opacity(0.65)
            }
            Text("Reserved for you.").font(AppFont.ui(9, weight: .medium)).opacity(0.75)
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
        .frame(width: 204, alignment: .leading)
        .foregroundStyle(ink)
        .background(Color(red: 0.67, green: 0.94, blue: 0.82), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.20)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your founding pass. Number \(number) of 200.")
    }
}
struct ConfirmationSeal: View {
    private let ink = Color(red: 0.08, green: 0.17, blue: 0.12)
    var body: some View {
        ZStack {
            if let url = Bundle.main.url(forResource: "FoundingSealGold", withExtension: "png"), let stamp = NSImage(contentsOf: url) {
                Image(nsImage: stamp).resizable().scaledToFit()
            }
        }.frame(width: 96, height: 96)
        .accessibilityLabel("Outloud license confirmed")
    }
}
struct LaunchUpdateNotification: View {
    var body: some View {
        HStack(spacing: 20) {
            ConfirmationSeal()
            VStack(alignment: .leading, spacing: 8) {
                Text("Your license is confirmed.").font(AppFont.ui(15, weight: .medium)).foregroundStyle(Color.white.opacity(0.93))
                Text("The full workspace arrives through an app update.").font(AppFont.ui(12)).foregroundStyle(Color.white.opacity(0.58))
                Text("Your first year starts with usable access.").font(AppFont.ui(11)).foregroundStyle(Color.white.opacity(0.42))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(white: 0.065), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
    }
}
