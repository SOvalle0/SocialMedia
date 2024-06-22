//
//  CreateNewPost.swift
//  SocialMedia
//
//  Created by Balaji on 25/12/22.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct CreateNewPost: View {
    /// - Callbacks
    var onPost: (Post)->()
    /// - Post Properties
    @State private var postText: String = ""
    @State private var postImageData: [Data] = []
    /// - Stored User Data From UserDefaults(AppStorage)
    @AppStorage("user_profile_url") private var profileURL: URL?
    @AppStorage("user_name") private var userName: String = ""
    @AppStorage("user_UID") private var userUID: String = ""
    /// - View Properties
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var photoItem: [PhotosPickerItem] = []
    @FocusState private var showKeyboard: Bool
    var body: some View {
        VStack{
            HStack{
                Menu {
                    Button("Cancel",role: .destructive){
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.callout)
                        .foregroundColor(.black)
                }
                .hAlign(.leading)
                
                Button(action: createPost){
                    Text("Post")
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal,20)
                        .padding(.vertical,6)
                        .background(.black,in: Capsule())
                }
                .disableWithOpacity(postText == "")
            }
            .padding(.horizontal,15)
            .padding(.vertical,10)
            .background {
                Rectangle()
                    .fill(.gray.opacity(0.05))
                    .ignoresSafeArea()
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 15){
                    TextField("What's happening?", text: $postText,axis: .vertical)
                        .focused($showKeyboard)
                    
                    PageTabView()
                }
                .padding(15)
            }
            
            Divider()
            
            HStack{
                Button {
                    showImagePicker.toggle()
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                }
                .hAlign(.leading)
                
                Button("Done"){
                    showKeyboard = false
                }
                .opacity(showKeyboard ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: showKeyboard)
            }
            .foregroundColor(.black)
            .padding(.horizontal,15)
            .padding(.vertical,10)
        }
        .vAlign(.top)
        .photosPicker(isPresented: $showImagePicker, selection: $photoItem, maxSelectionCount: 4, selectionBehavior: .ordered)
        .onChange(of: photoItem) { newValue in
            if !newValue.isEmpty{
                Task{
                    /// - Extracting Images From the Array of Photo Items
                    /// - Resizing Image
                    /// - You can change this for your Appropiate size
                    /// - Resizing saves lots of meomory
                    /// - MODIFY STARTS
                    let compressedSize = CGSize(width: 1080, height: 1080)
                    let compression: CGFloat = 0.55
                    /// - MODIFICATION ENDS
                    
                    var compressedImages: [Data] = []
                    for item in photoItem{
                        if let rawImageData = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: rawImageData),
                           let compressedImageData = image.resizeImage(to: compressedSize)?.jpegData(compressionQuality: compression){
                            compressedImages.append(compressedImageData)
                        }
                    }
                    /// UI Must be done on Main Thread
                    await MainActor.run(body: {
                        postImageData = compressedImages
                        photoItem = []
                    })
                }
            }
        }
        .alert(errorMessage, isPresented: $showError, actions: {})
        /// - Loading View
        .overlay {
            LoadingView(show: $isLoading)
        }
    }
    
    /// - Selected Photos Pager View
    @ViewBuilder
    func PageTabView()->some View{
        if !postImageData.isEmpty{
            TabView {
                ForEach(postImageData.indices,id: \.self){index in
                    let imageData = postImageData[index]
                    if let image = UIImage(data: imageData){
                        GeometryReader{
                            let size = $0.size
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size.width - 10, height: size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                /// - Delete Button
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)){
                                            let _ = postImageData.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .fontWeight(.bold)
                                            .tint(.red)
                                    }
                                    .padding(10)
                                }
                                .hAlign(.center)
                        }
                    }
                }
            }
            .tabViewStyle(.page)
            .clipped()
            .frame(height: 220)
        }
    }
    
    // MARK: Post Content To Firebase
    func createPost(){
        isLoading = true
        showKeyboard = false
        Task{
            do{
                guard let profileURL = profileURL else{return}
                
                if postImageData.isEmpty{
                    ///  Directly Post Text Data to Firebase (Since there is no Images Present)
                    let post = Post(text: postText, userName: userName, userUID: userUID, userProfileURL: profileURL)
                    try await createDocumentAtFirebase(post)
                }else{
                    /// Uploading Images If any
                    /// - ReferenceID: Used to delete the Post(Later shown in the Video)
                    var referenceIDs: [String] = []
                    var downloadURLs: [URL] = []
                    for imageData in postImageData{
                        let imageReferenceID = "\(userUID)\(Date())"
                        let storageRef = Storage.storage().reference().child("Post_Images").child(imageReferenceID)
                        let _ = try await storageRef.putDataAsync(imageData)
                        let downloadURL = try await storageRef.downloadURL()
                        referenceIDs.append(imageReferenceID)
                        downloadURLs.append(downloadURL)
                    }
                    
                    /// Create Post Object With Image Id And URL
                    let post = Post(text: postText, imageURLs: downloadURLs, imageReferenceIDs: referenceIDs, userName: userName, userUID: userUID, userProfileURL: profileURL)
                    try await createDocumentAtFirebase(post)
                }
            }catch{
                await setError(error)
            }
        }
    }
    
    func createDocumentAtFirebase(_ post: Post)async throws{
        /// - Writing Document to Firebase Firestore
        let doc = Firestore.firestore().collection("Posts").document()
        let _ = try doc.setData(from: post, completion: { error in
            if error == nil{
                /// Post Successfully Stored at Firebase
                isLoading = false
                var updatedPost = post
                updatedPost.id = doc.documentID
                onPost(updatedPost)
                dismiss()
            }
        })
    }
    
    // MARK: Displaying Errors as Alert
    func setError(_ error: Error)async{
        await MainActor.run(body: {
            errorMessage = error.localizedDescription
            showError.toggle()
        })
    }
}

struct CreateNewPost_Previews: PreviewProvider {
    static var previews: some View {
        CreateNewPost{_ in
            
        }
    }
}
