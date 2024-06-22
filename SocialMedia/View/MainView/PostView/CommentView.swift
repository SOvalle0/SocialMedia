//
//  CommentView.swift
//  SocialMedia
//
//  Created by Balaji on 30/12/22.
//

import SwiftUI
import FirebaseFirestore

struct CommentView: View {
    var post: Post
    // MARK: View Properties
    @State private var commentText: String = ""
    @State private var fetchedComments: [Comment] = []
    @State private var isFetching: Bool = true
    @State private var paginationDoc: QueryDocumentSnapshot?
    // MARK: User Defaults Data
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_UID") private var userUID: String = ""
    var body: some View {
        NavigationStack{
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10){
                    ForEach(fetchedComments) { comment in
                        CommentRow(comment)
                            .onAppear {
                                if fetchedComments.last?.id == comment.id && paginationDoc != nil && fetchedComments.count > 19{
                                    Task{await fetchComments()}
                                }
                            }
                    }
                }
                .padding(15)
            }
            .overlay(content: {
                if isFetching{
                    ProgressView()
                }
            })
            .safeAreaInset(edge: .bottom) {
                HStack{
                    TextField("Comment", text: $commentText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: addComment) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .contentShape(Rectangle())
                    }
                    .disableWithOpacity(commentText == "")
                }
                .tint(.black)
                .padding(15)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Comment's")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .task {
            guard fetchedComments.isEmpty else{return}
            await fetchComments()
        }
    }
    
    /// - Comment Row
    @ViewBuilder
    func CommentRow(_ comment: Comment)->some View{
        VStack(spacing: 12){
            VStack(alignment: .leading,spacing: 8) {
                HStack{
                    Text(comment.userName)
                        .font(.caption)
                    
                    Text(comment.postedTime.formatted(date: .numeric, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .hAlign(.trailing)
                }
                
                Text(comment.comment)
            }
            .hAlign(.leading)
            
            Divider()
        }
        .overlay(alignment: .bottomTrailing, content: {
            if comment.userUID == userUID{
                Menu {
                    Button("Delete Comment",role: .destructive){
                        deleteComment(comment)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .rotationEffect(.init(degrees: 90))
                        .padding(15)
                        .contentShape(Rectangle())
                }
                .offset(x: 15)
            }
        })
        .contentShape(Rectangle())
    }
    
    /// - Fetching Comments for the ID
    func fetchComments()async{
        guard let postID = post.id else{return}
        do{
            var query: Query!
            if let paginationDoc{
                query = Firestore.firestore().collection("Posts")
                    .document(postID)
                    .collection("Comments")
                    .order(by: "postedTime", descending: true)
                    .start(afterDocument: paginationDoc)
                    .limit(to: 20)
            }else{
                query = Firestore.firestore().collection("Posts")
                    .document(postID)
                    .collection("Comments")
                    .order(by: "postedTime", descending: true)
                    .limit(to: 20)
            }
            
            let docs = try await query.getDocuments()
            let comments = try docs.documents.compactMap { doc -> Comment? in
                try doc.data(as: Comment.self)
            }
            await MainActor.run(body: {
                fetchedComments.append(contentsOf: comments)
                paginationDoc = docs.documents.last
                isFetching = false
            })
        }catch{
            print(error.localizedDescription)
        }
    }
    
    /// - Adding Comment
    func addComment(){
        Task{
            do{
                guard let postID = post.id else{return}
                var comment = Comment(comment: commentText, userName: userName, userUID: userUID)
                let docRef = Firestore.firestore().collection("Posts").document(postID)
                    .collection("Comments")
                    .document()
                try docRef.setData(from: comment, completion: { error in
                    if error == nil{
                        comment.id = docRef.documentID
                        fetchedComments.insert(comment, at: 0)
                        commentText = ""
                    }
                })
            }catch{
                print(error.localizedDescription)
            }
        }
    }
    
    /// - Delete Comment
    func deleteComment(_ comment: Comment){
        Task{
            do{
                guard let postID = post.id else{return}
                guard let commentID = comment.id else{return}
                
                try await Firestore.firestore().collection("Posts").document(postID)
                    .collection("Comments")
                    .document(commentID)
                    .delete()
                if let index = fetchedComments.firstIndex(where: { item in
                    item.id == comment.id
                }){
                    await MainActor.run(body: {
                       let _ = withAnimation(.easeInOut(duration: 0.2)){
                            fetchedComments.remove(at: index)
                        }
                    })
                }
            }catch{
                print(error.localizedDescription)
            }
        }
    }
}
