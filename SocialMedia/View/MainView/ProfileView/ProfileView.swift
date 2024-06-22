//
//  ProfileView.swift
//  SocialMedia
//
//  Created by Balaji on 14/12/22.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseFirestore

struct ProfileView: View {
    // MARK: My Profile Data
    @State private var myProfile: User?
    // MARK: User Defaults Data
    @AppStorage("user_profile_url") private var profileURL: URL?
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_UID") private var userUID: String = ""
    @AppStorage("log_status") private var logStatus: Bool = false
    // MARK: View Properties
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isLoading: Bool = false
    /// - For some cases Re-Authentication Required for Auth Deletion
    @State private var emailID: String = ""
    @State private var password: String = ""
    @State private var promptAuth: Bool = false
    var body: some View {
        NavigationStack{
            VStack{
                if let myProfile{
                    ReusableProfileContent(user: myProfile)
                        .refreshable {
                            // MARK: Refresh User Data
                            self.myProfile = nil
                            await fetchUserData()
                        }
                }else{
                    ProgressView()
                }
            }
            .navigationTitle("My Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // MARK: Two Action's
                        // 1. Logout
                        // 2. Delete Account
                        Button("Logout",action: logOutUser)
                        
                        Button("Delete Account",role: .destructive){
                            promptAuth.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.init(degrees: 90))
                            .tint(.black)
                            .scaleEffect(0.8)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .toolbar(isLoading ? .hidden : .visible, for: .tabBar)
        .overlay {
            LoadingView(show: $isLoading)
        }
        /// - Asking User to Re-Authenticate for Confiming Account Deletion
        .alert("Input Credential for confirming deletion", isPresented: $promptAuth, actions: {
            TextField("Email ID", text: $emailID)
            SecureField("Password", text: $password)
            Button("Delete",role: .destructive){
                isLoading = true
                Task{
                    do{
                        let recentCredential = EmailAuthProvider.credential(withEmail: emailID, password: password)
                        try await deleteAccount(recentCredential)
                    }catch{
                        await setError(error)
                    }
                }
            }
        })
        .alert(errorMessage, isPresented: $showError) {}
        .task {
            // This Modifer is like onAppear
            // So Fetching for the First Time Only
            if myProfile != nil{return}
            // MARK: Initial Fetch
            await fetchUserData()
        }
    }
    
    // MARK: Fetching User Data
    func fetchUserData()async{
        guard let userUID = Auth.auth().currentUser?.uid else{return}
        guard let user = try? await Firestore.firestore().collection("Users").document(userUID).getDocument(as: User.self) else{return}
        await MainActor.run(body: {
            myProfile = user
        })
    }
    
    // MARK: Logging User Out
    func logOutUser(){
        try? Auth.auth().signOut()
        userUID = ""
        userName = ""
        profileURL = nil
        logStatus = false
    }
    
    // MARK: Deleting User Entire Account
    func deleteAccount(_ credential: AuthCredential)async throws{
        /// - Re-Authenticating User
        try await Auth.auth().currentUser?.reauthenticate(with: credential)
        guard let userUID = Auth.auth().currentUser?.uid else{return}
        
        // Step 1: Deleting User's All Post's with Images
        /// - NOTE: THIS WILL TAKE SOME MUCH TIME WHEN THERE ARE PLENTY OF USER POSTS
        /// - ALSO IT WILL NOT DELETE ITS COMMENTS SINCE IT'S A SUBCOLLECTION
        /// - ALTERNATIVELY YOU CAN SCHEDULE THE POST DELETION LIKE INSTAGRAM BY WRITING THE SAME CODE WITH ADVANCEMENT ON NODE.JS USING FIREBASE-ADMIN TOOLS
        /// - ELSE SKIP THIS PART, BUT ALL OF THE USER POST WILL REMAINS UNDELETED
        let posts = try await Firestore.firestore().collection("Posts").whereField("userUID", isEqualTo: userUID).getDocuments()
        for post in posts.documents{
            try await deletePost(post: post.data(as: Post.self))
        }
        
        // Step 2: Deleting Profile Image From Storage
        let reference = Storage.storage().reference().child("Profile_Images").child(userUID)
        try await reference.delete()
        
        // Step 3: Deleting Firestore User Document
        try await Firestore.firestore().collection("Users").document(userUID).delete()
        
        // Final Step: Deleting Auth Account and Setting Log Status to False
        try await Auth.auth().currentUser?.delete()
        await MainActor.run(body: {
            logStatus = false
        })
    }
    
    /// - Deleting Post
    func deletePost(post: Post)async throws{
        for id in post.imageReferenceIDs{
            try await Storage.storage().reference().child("Post_Images").child(id).delete()
        }
        /// Step 2: Delete Firestore Document
        guard let postID = post.id else{return}
        try await Firestore.firestore().collection("Posts").document(postID).delete()
    }
    
    // MARK: Setting Error
    func setError(_ error: Error)async{
        // MARK: UI Must be run on Main Thread
        await MainActor.run(body: {
            isLoading = false
            errorMessage = error.localizedDescription
            showError.toggle()
            emailID = ""
            password = ""
        })
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
