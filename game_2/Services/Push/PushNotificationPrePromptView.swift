import Combine
import SwiftUI
import UIKit

// MARK: - UIKit host (вызывается из SwiftUI)

@MainActor
protocol PushNotificationPrePromptScreenHost: AnyObject {
    func pushPrePromptAllowTapped()
    func pushPrePromptSkipTapped()
}

@MainActor
final class PushNotificationPrePromptScreenModel: ObservableObject {
    weak var host: PushNotificationPrePromptScreenHost?

    @Published private(set) var isLandscape = false

    func updateIsLandscape(_ value: Bool) {
        guard isLandscape != value else { return }
        isLandscape = value
    }
}

extension PushNotificationPrePromptScreenModel {
    func reportUserChoseAllow() {
        host?.pushPrePromptAllowTapped()
    }

    func reportUserChoseSkip() {
        host?.pushPrePromptSkipTapped()
    }
}

// MARK: - SwiftUI (вёрстку замените здесь)

struct PushNotificationPrePromptView: View {
    @ObservedObject var model: PushNotificationPrePromptScreenModel

    var body: some View {
        GeometryReader { geo in
            let land = geo.size.width > geo.size.height
            ZStack(content: {
                Image(land ? .notificationBGHorizontal : .notificationsBGVertical)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                if land {
                    horizontalContent
                } else {
                    verticalConeent
                }
            })
                .accessibilityIdentifier("pushPrePrompt.root")
                .onAppear {
                    model.updateIsLandscape(land)
                }
                .onChange(of: geo.size) { _, new in
                    model.updateIsLandscape(new.width > new.height)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Вызовы: model.reportUserChoseAllow() / model.reportUserChoseSkip()
        // Ориентация: model.isLandscape
    }
    
    private var horizontalContent: some View {
        VStack(spacing: 8) {
            Image(.notificationTitleHorizontal)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 96)
            
            VStack(spacing: 8) {
                Button {
                    model.reportUserChoseAllow()
                } label: {
                    Image(.yesHorizontal)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
                Button {
                    model.reportUserChoseSkip()
                } label: {
                    Image(.skip)
                        .resizable()
                        .frame(width: 46, height: 18)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
    }
    
    private var verticalConeent: some View {
        VStack(spacing: 30) {
            Image(.notificationTitleVertical)
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            VStack(spacing: 16) {
                Button {
                    model.reportUserChoseAllow()
                } label: {
                    Image(.yesVertical)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
                Button {
                    model.reportUserChoseSkip()
                } label: {
                    Image(.skip)
                        .resizable()
                        .frame(width: 46, height: 18)
                }
            }
        }
        .padding(.horizontal, 46)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 126)
    }
}

#if DEBUG
#Preview("Push pre-prompt") {
    final class PreviewHost: PushNotificationPrePromptScreenHost {
        func pushPrePromptAllowTapped() {}
        func pushPrePromptSkipTapped() {}
    }

    let model = PushNotificationPrePromptScreenModel()
    model.host = PreviewHost()
    return PushNotificationPrePromptView(model: model)
        .background(Color(uiColor: .systemBackground))
}
#endif
