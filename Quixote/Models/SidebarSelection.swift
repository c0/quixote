import Foundation

enum SidebarSelection: Equatable {
    case data(UUID)
    case pinnedPrompt(UUID)
}
