import SwiftUI

struct SessionDetailView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  let sessionId: String

  private var currentSession: WatchSession? {
    connectivity.snapshot.sessions.first { $0.id == sessionId }
  }

  var body: some View {
    Group {
      if let session = currentSession {
        sessionContent(session)
      } else {
        ContentUnavailableView(
          "Request resolved",
          systemImage: "checkmark.circle",
          description: Text("This session is no longer active.")
        )
      }
    }
    .navigationTitle(currentSession?.title ?? "Session")
    .onAppear(perform: connectivity.clearActionMessage)
  }

  private func sessionContent(_ session: WatchSession) -> some View {
    List {
      Section {
        Label(session.statusLabel, systemImage: session.providerSymbol)
          .foregroundStyle(session.statusColor)
        if !session.branch.isEmpty {
          Label(session.branch, systemImage: "arrow.triangle.branch")
            .font(.caption)
        }
        if !session.lastMessage.isEmpty {
          Text(session.lastMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(4)
        }
      }

      if let permission = session.permission {
        Section("Needs you") {
          if permission.requiresPhone {
            Label("Open on iPhone", systemImage: "iphone")
              .foregroundStyle(Color.ccpocketApproval)
          } else if permission.kind == "question", !permission.questions.isEmpty {
            NavigationLink {
              QuestionFlowView(session: session, permission: permission)
            } label: {
              Label("Answer", systemImage: "text.bubble")
                .foregroundStyle(Color.ccpocketApproval)
            }
          } else {
            NavigationLink {
              ApprovalView(session: session, permission: permission)
            } label: {
              Label("Review request", systemImage: "checkmark.shield")
                .foregroundStyle(Color.ccpocketApproval)
            }
          }
        }
      }

      Section {
        NavigationLink {
          QuickMessageView(session: session)
        } label: {
          Label("Send message", systemImage: "mic")
        }
      }

      if let message = connectivity.actionMessage {
        Text(message)
          .font(.caption2)
          .foregroundStyle(
            message == "Sent" ? Color.ccpocketOnline : Color.secondary
          )
      }
    }
  }
}

private struct ApprovalView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  let session: WatchSession
  let permission: WatchPermission
  @State private var submitted = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Label(permission.title, systemImage: "exclamationmark.shield")
          .font(.headline)
          .foregroundStyle(Color.ccpocketApproval)
        if !permission.summary.isEmpty {
          Text(permission.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if submitted {
          Label("Sent", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(Color.ccpocketOnline)
        } else if permission.canApprove {
          Button {
            connectivity.approve(session: session, permission: permission) {
              submitted = $0
            }
          } label: {
            Label("Approve", systemImage: "checkmark")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.ccpocketOnline)
        }
        if !submitted && permission.canReject {
          Button(role: .destructive) {
            connectivity.reject(session: session, permission: permission) {
              submitted = $0
            }
          } label: {
            Label("Reject", systemImage: "xmark")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
        if !submitted, let message = connectivity.actionMessage {
          Text(message)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .disabled(connectivity.isSending)
    .navigationTitle("Approval")
    .onAppear(perform: connectivity.clearActionMessage)
  }
}

private struct QuestionFlowView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  let session: WatchSession
  let permission: WatchPermission

  @State private var currentIndex = 0
  @State private var answers: [String: Set<String>] = [:]
  @State private var customText = ""
  @State private var submitted = false

  private var question: WatchQuestion {
    permission.questions[currentIndex]
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        if submitted {
          Label("Sent", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(Color.ccpocketOnline)
        } else {
          QuestionHeader(
            question: question,
            current: currentIndex + 1,
            total: permission.questions.count
          )
          ForEach(question.options) { option in
            Button {
              select(option.value)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 1) {
                  Text(option.label)
                  if !option.description.isEmpty {
                    Text(option.description)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(2)
                  }
                }
                Spacer(minLength: 4)
                if answers[question.key]?.contains(option.value) == true {
                  Image(systemName: "checkmark")
                }
              }
            }
            .buttonStyle(.bordered)
            .tint(.ccpocketOrange)
          }

          if permission.allowsCustomInput {
            TextField("Speak or type", text: $customText)
              .submitLabel(.done)
              .onSubmit(submitCustomText)
            Button(action: submitCustomText) {
              Label("Use response", systemImage: "mic")
                .frame(maxWidth: .infinity)
            }
            .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }

          if question.multiSelect || !question.required {
            Button(action: advance) {
              Text(isLastQuestion ? "Send" : "Continue")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(question.required && (answers[question.key]?.isEmpty ?? true))
          }
          if let message = connectivity.actionMessage {
            Text(message)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .disabled(connectivity.isSending)
    .navigationTitle(question.header.isEmpty ? "Question" : question.header)
    .onAppear(perform: connectivity.clearActionMessage)
  }

  private var isLastQuestion: Bool {
    currentIndex == permission.questions.count - 1
  }

  private func select(_ label: String) {
    if question.multiSelect {
      var selected = answers[question.key] ?? []
      if selected.contains(label) {
        selected.remove(label)
      } else {
        selected.insert(label)
      }
      answers[question.key] = selected
    } else {
      answers[question.key] = [label]
      advance()
    }
  }

  private func submitCustomText() {
    let value = customText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    if question.multiSelect {
      answers[question.key, default: []].insert(value)
    } else {
      answers[question.key] = [value]
    }
    customText = ""
    advance()
  }

  private func advance() {
    if isLastQuestion {
      connectivity.answer(
        session: session,
        permission: permission,
        answers: answers.mapValues(Array.init)
      ) { accepted in
        submitted = accepted
      }
    } else {
      currentIndex += 1
      customText = ""
    }
  }
}

private struct QuestionHeader: View {
  let question: WatchQuestion
  let current: Int
  let total: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      if total > 1 {
        Text("\(current) of \(total)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Text(question.text)
        .font(.headline)
    }
  }
}

private struct QuickMessageView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  @Environment(\.dismiss) private var dismiss
  let session: WatchSession
  @State private var text = ""

  var body: some View {
    VStack(spacing: 10) {
      TextField("Speak or type", text: $text)
        .submitLabel(.send)
        .onSubmit(send)
      Button(action: send) {
        Label("Send", systemImage: "arrow.up.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      if let message = connectivity.actionMessage {
        Text(message)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .disabled(connectivity.isSending)
    .navigationTitle("Message")
    .onAppear(perform: connectivity.clearActionMessage)
  }

  private func send() {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    connectivity.sendInput(session: session, text: value) { accepted in
      if accepted {
        dismiss()
      }
    }
  }
}
