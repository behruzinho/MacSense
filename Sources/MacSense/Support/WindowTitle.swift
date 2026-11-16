import SwiftUI

/// Keeps native window chrome in sync with the app's selected language.
struct WindowTitle: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> TitleView { TitleView() }

    func updateNSView(_ nsView: TitleView, context: Context) {
        nsView.title = title
    }

    final class TitleView: NSView {
        var title = "" {
            didSet { updateTitle() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateTitle()
        }

        private func updateTitle() {
            window?.title = title
            // SwiftUI can assign the scene's default title during window attachment.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.title = self.title
            }
        }
    }
}
