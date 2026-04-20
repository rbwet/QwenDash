import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    var content: String
    var createdAt: Date = .init()
    /// True while the assistant is actively streaming into this message.
    var isStreaming: Bool = false

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
            && lhs.role == rhs.role
            && lhs.content == rhs.content
            && lhs.isStreaming == rhs.isStreaming
    }
}
