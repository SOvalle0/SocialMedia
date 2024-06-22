//
//  PostCardView.swift
//  SocialMedia
//
//  Created by Balaji on 25/12/22.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore
import FirebaseStorage

struct PostCardView: View {
    var post: Post
    /// - Callbacks
    var onUpdate: (Post)->()
    var onDelete: ()->()
    /// - View Properties
    @AppStorage("user_UID") private var userUID: String = ""
    @State private var docListner: ListenerRegistration?
    @State private var showComments: Bool = false
    @State private var expandImages: Bool = false
    @State private var pageIndex: Int = 0
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WebImage(url: post.userProfileURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 35, height: 35)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(post.userName)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(post.publishedDate.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(post.text)
                    .textSelection(.enabled)
                    .padding(.vertical,8)
                
                /// Post Images If Any
                if !post.imageURLs.isEmpty{
                    TabView(selection: $pageIndex){
                        ForEach(post.imageURLs,id: \.self){url in
                            let index = post.imageURLs.indexOf(url)
                            GeometryReader{
                                let size = $0.size
                                WebImage(url: url,options: [.scaleDownLargeImages,.lowPriority])
                                    .purgeable(true)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size.width - 10, height: size.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .hAlign(.center)
                            }
                            .tag(index)
                            .frame(height: 200)
                            .onTapGesture {
                                expandImages.toggle()
                                pageIndex = index
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 200)
                    .fullScreenCover(isPresented: $expandImages) {
                        ExpandedImagesView(imageURLs: post.imageURLs, pageIndex: $pageIndex)
                    }
                }
                
                PostInteraction()
            }
        }
        .hAlign(.leading)
        .sheet(isPresented: $showComments, content: {
            CommentView(post: post)
        })
        .overlay(alignment: .topTrailing, content: {
            /// Displaying Delete Button (if it's Author of that post)
            if post.userUID == userUID{
                Menu {
                    Button("Delete Post",role: .destructive,action: deletePost)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .rotationEffect(.init(degrees: -90))
                        .foregroundColor(.black)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .offset(x: 8)
            }
        })
        .onAppear {
            /// - Adding Only Once
            if docListner == nil{
                guard let postID = post.id else{return}
                docListner = Firestore.firestore().collection("Posts").document(postID).addSnapshotListener({ snapshot, error in
                    if let snapshot{
                        if snapshot.exists{
                            /// - Document Updated
                            /// Fetching Updated Document
                            if let updatedPost = try? snapshot.data(as: Post.self){
                                onUpdate(updatedPost)
                            }
                        }else{
                            /// - Document Deleted
                            onDelete()
                        }
                    }
                })
            }
        }
        .onDisappear {
            // MARK: Applying SnapShot Listner Only When the Post is Available on the Screen
            // Else Removing the Listner (It saves unwanted live updates from the posts which was swiped away from the screen)
            if let docListner{
                docListner.remove()
                self.docListner = nil
            }
        }
    }
    
    // MARK: Like/Dislike Interaction
    @ViewBuilder
    func PostInteraction()->some View{
        HStack(spacing: 6){
            Button(action: likePost){
                Image(systemName: post.likedIDs.contains(userUID) ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            
            Text("\(post.likedIDs.count)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: dislikePost){
                Image(systemName: post.dislikedIDs.contains(userUID) ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .padding(.leading,25)
            
            Text("\(post.dislikedIDs.count)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: {showComments.toggle()}) {
                Image(systemName: "message")
            }
            .padding(.leading,25)
        }
        .foregroundColor(.black)
        .padding(.vertical,8)
    }
    
    /// - Liking Post
    func likePost(){
        Task{
            guard let postID = post.id else{return}
            if post.likedIDs.contains(userUID){
                /// Removing User ID From the Array
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "likedIDs": FieldValue.arrayRemove([userUID])
                ])
            }else{
                /// Adding User ID To Liked Array and removing our ID from Disliked Array (if Added in prior)
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "likedIDs": FieldValue.arrayUnion([userUID]),
                    "dislikedIDs": FieldValue.arrayRemove([userUID])
                ])
            }
        }
    }
    
    /// - Dislike Post
    func dislikePost(){
        Task{
            guard let postID = post.id else{return}
            if post.dislikedIDs.contains(userUID){
                /// Removing User ID From the Array
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "dislikedIDs": FieldValue.arrayRemove([userUID])
                ])
            }else{
                /// Adding User ID To Liked Array and removing our ID from Disliked Array (if Added in prior)
                try await Firestore.firestore().collection("Posts").document(postID).updateData([
                    "likedIDs": FieldValue.arrayRemove([userUID]),
                    "dislikedIDs": FieldValue.arrayUnion([userUID])
                ])
            }
        }
    }
    
    /// - Deleting Post
    func deletePost(){
        Task{
            /// Step 1: Delete Image from Firebase Storage if present
            do{
                for id in post.imageReferenceIDs{
                    try await Storage.storage().reference().child("Post_Images").child(id).delete()
                }
                /// Step 2: Delete Firestore Document
                guard let postID = post.id else{return}
                try await Firestore.firestore().collection("Posts").document(postID).delete()
            }catch{
                print(error.localizedDescription)
            }
        }
    }
}

extension [URL]{
    func indexOf(_ url: URL)->Int{
        if let index = self.firstIndex(of: url){
            return index
        }
        return 0
    }
}
