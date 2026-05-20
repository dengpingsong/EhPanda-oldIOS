//
//  PostCommentView.swift
//  EhPanda
//

import SwiftUI

struct PostCommentView: View {
    private let title: String
    @Binding private var content: String
    @Binding private var isFocused: Bool
    private let postAction: () -> Void
    private let cancelAction: () -> Void
    private let onAppearAction: () -> Void

    @FocusState private var isTextEditorFocused: Bool

    init(
        title: String,
        content: Binding<String>,
        isFocused: Binding<Bool>,
        postAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        onAppearAction: @escaping () -> Void
    ) {
        self.title = title
        _content = content
        _isFocused = isFocused
        self.postAction = postAction
        self.cancelAction = cancelAction
        self.onAppearAction = onAppearAction
    }

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $content)
                    .focused($isTextEditorFocused)
                    .padding()

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancelAction) {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: postAction) {
                        Text("Post")
                    }
                        .disabled(content.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
        }
        .synchronize($isFocused, $isTextEditorFocused)
        .onAppear(perform: onAppearAction)
    }
}
