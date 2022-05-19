import Foundation
import Firebase


final class DatabaseManager {
    static let shared: DatabaseManager = DatabaseManager()
    
    private var reference: DatabaseReference!
    private var storage: StorageReference!
    private var infoReference: DatabaseReference!
    
    private init() {
        storage = Storage.storage().reference()
        reference = Database.database().reference()
        infoReference = Database.database().reference(withPath: ".info/connected")
    }
    
    public var currentUserUID: String? {
        get {
            Auth.auth().currentUser?.uid
        }
    }
    
    public func getAccountInfo(uid: String, completion: @escaping (Result<MyAccountInfo, Error>) -> Void) {
        
        reference.child("users").child(uid).getData() { error, snapshot in
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
            let accountInfo = MyAccountInfo(snapshot: snapshot, uid: uid)
            DispatchQueue.main.async {
                completion(.success(accountInfo))
            }
        }
    }
    
    public func getMyAccountPosts(userName: String, userImage: String, postKey: String, completion: @escaping (Result<MyAccountPost, Error>) -> Void) {
        
        reference.child("posts").child(postKey).getData() { error, snapshot in
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            let accountPost = MyAccountPost(userName: userName, userImage: userImage, snapshot: snapshot)
            DispatchQueue.main.async {
                completion(.success(accountPost))
            }
        }
    }
    
    public func removePostFromUserPosts(postKeys: [String], completion: @escaping (Result <Void, Error>) -> Void) {
        guard let strongCurrentUserUID = DatabaseManager.shared.currentUserUID else {
            completion(.failure(NSError()))
            return
        }
        
        reference.child("users").child(strongCurrentUserUID).child("posts").setValue(postKeys) { error, _ in
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            completion(.success(Void()))
        }
    }
    
    public func removePostFromPosts(postKey: String, completion: @escaping (Result <Void, Error>) -> Void) {
        reference.child("posts").child(postKey).setValue(nil) { error, _ in
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            completion(.success(Void()))
        }
    }
    
    
    public func removeImageFromStorage(imageKey: String, completion: @escaping (Result <Void, Error>) -> Void) {
        storage.child("posts").child(imageKey).delete { error in
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            completion(.success(Void()))
        }
    }
    
    public func getImage(destination: String, postImageKey: String, completion: @escaping (Result<Data, Error>) -> Void) {
        
        storage.child(destination).child(postImageKey).getData(maxSize: 1024 * 1024 * 100) { data, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            if let data = data {
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            }
        }
    }
    
    public func removePublisher(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let strongCurrentUserUID = currentUserUID else {
            completion(.failure(NSError()))
            return
        }
        reference.child("users").child(strongCurrentUserUID).child("publishers").getData() { [weak self] error, snapshot in
            guard let strongSelf = self else { return }
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            guard var publishers = snapshot.value as? [String] else {
                return
            }
            guard let index = publishers.firstIndex(of: uid) else { return }
            publishers.remove(at: index)
            strongSelf.reference.child("users").child(strongCurrentUserUID).child("publishers").setValue(publishers) { error, _ in
                guard error == nil else {
                    completion(.failure(NSError()))
                    return
                }
                completion(.success(Void()))
            }
        }
    }
    
    public func decreaseSubscribersNumber(uid: String,  completion: @escaping (Result<Void, Error>) -> Void) {
        reference.child("users").child(uid).child("subscribers").getData() { [weak self] error, snapshot in
            guard let strongSelf = self else { return }
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            guard let subNum = snapshot.value as? Int else {
                completion(.failure(NSError()))
                return
            }
            strongSelf.reference.child("users").child(uid).child("subscribers").setValue(subNum - 1) { error, _ in
                guard error == nil else {
                    completion(.failure(NSError()))
                    return
                }
                completion(.success(Void()))
            }
        }
    }
    
    
    public func addPublisher(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let strongCurrentUserUID = currentUserUID else {
            completion(.failure(NSError()))
            return
        }
        reference.child("users").child(strongCurrentUserUID).child("publishers").getData() { [weak self] error, snapshot in
            guard let strongSelf = self else { return }
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            var publishArray: [String] = []
            if let publishers = snapshot.value as? [String] {
                publishArray = publishers
            }
            publishArray.append(uid)
            strongSelf.reference.child("users").child(strongCurrentUserUID).child("publishers").setValue(publishArray) { error, _ in
                guard error == nil else {
                    completion(.failure(NSError()))
                    return
                }
                completion(.success(Void()))
            }
        }
    }
    
    public func increaseSubscribersNumber(uid: String,  completion: @escaping (Result<Void, Error>) -> Void) {
        reference.child("users").child(uid).child("subscribers").getData() { [weak self] error, snapshot in
            guard let strongSelf = self else { return }
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            guard let subNum = snapshot.value as? Int else {
                completion(.failure(NSError()))
                return
            }
            strongSelf.reference.child("users").child(uid).child("subscribers").setValue(subNum + 1) { error, _ in
                guard error == nil else {
                    completion(.failure(NSError()))
                    return
                }
                completion(.success(Void()))
            }
        }
    }
    
    public func getPublishers(uid: String, completion: @escaping (Result<DataSnapshot, Error>) -> Void) {
        
        reference.child("users").child(uid).child("publishers").getData() { error, snapshot in
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            completion(.success(snapshot))
        }
    }
    
    public func addPost(postData: PostModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let keyPost = reference.child("posts").childByAutoId().key else {
            completion(.failure(AddPostError.serverError))
            return
        }
        
        let keysImages: [String] = postData.keysImages.map { _ in
            UUID().uuidString
        }
        
        let data: [String: Any] = [
            "uid" : postData.uid,
            "title" : postData.title,
            "latitude" : postData.latitude,
            "longitude" : postData.longitude,
            "address" : postData.address,
            "comment" : postData.comment,
            "keysImages" : keysImages,
            "day" : postData.day,
            "month" : postData.month,
            "year" : postData.year,
            "mark" : postData.mark
        ]
        
        reference.child("posts").child(keyPost).setValue(data) { [weak self] error, _ in
            guard let self = self else {
                completion(.failure(AddPostError.unknownError))
                return
            }
            
            guard error == nil else {
                completion(.failure(AddPostError.serverError))
                return
            }
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            for indexPost in (0 ..< keysImages.count) {
                let url = URL(fileURLWithPath: postData.keysImages[indexPost])
                
                guard let dataImage = try? Data(contentsOf: url) else {
                    completion(.failure(AddPostError.serverError))
                    return
                }
                
                self.storage.child("posts").child(keysImages[indexPost]).putData(dataImage, metadata: metadata) { metadata, error in
                    guard error == nil else {
                        completion(.failure(AddPostError.serverError))
                        return
                    }
                }
            }
            
            self.reference.child("users").child(postData.uid).child("posts").getData { error, snapshot in
                guard error == nil else {
                    completion(.failure(AddPostError.serverError))
                    return
                }
                
                var arrayPosts = snapshot.value as? [String] ?? Array<String>()
                arrayPosts.append(keyPost)
                
                self.reference.child("users").child(postData.uid).child("posts").setValue(arrayPosts) { error, _ in
                    guard error == nil else {
                        completion(.failure(AddPostError.serverError))
                        return
                    }
                }
            }
            completion(.success(Void()))
        }
    }
    
    public func addUser(userData: UserModel, completion: ((Result<Void, Error>) -> Void)?) {
        let data: [String: Any] = [
            "uid" : userData.uid,
            "username" : userData.username,
            "email" : userData.email,
            "password" : userData.password,
            "avatar" : userData.avatar ?? "",
            "subscribers" : 0,
            "publishers": [],
            "posts" : [],
            "favourite" : []
        ]
        
        reference.child("users").child(userData.uid).setValue(data) { error, _ in
            guard error == nil else {
                completion?(.failure(NSError()))
                return
            }
            
            completion?(.success(Void()))
        }
    }
    
    
    public func addPostToChart(idPost: String, isAppend: Bool, completion: @escaping ((Result<Void, Error>) -> Void)) {
        guard let curUID = DatabaseManager.shared.currentUserUID else {
            completion(.failure(NSError()))
            return
        }
        
        reference.child("users").child(curUID).child("favourite").getData { error, snapshot in
            guard error == nil else {
                completion(.failure(NSError()))
                return
            }
            
            var chartPosts = snapshot.value as? [String] ?? []
            if !chartPosts.contains(idPost) && isAppend {
                chartPosts.append(idPost)
            } else if chartPosts.contains(idPost) && !isAppend {
                chartPosts = chartPosts.filter({
                    $0 != idPost
                })
            }
            
            self.reference.child("users").child(curUID).child("favourite").setValue(chartPosts) { error, _ in
                guard error == nil else {
                    completion(.failure(NSError()))
                    return
                }
                
                completion(.success(Void()))
            }
        }
    }
    
    
    public func fetchLocalDataPost(idPost: String, completion: @escaping (Bool, Double, Double) -> Void) {
        guard let curUID = DatabaseManager.shared.currentUserUID else {
            completion(false, 54.0, 54.0)
            return
        }
        
        reference.child("users").child(curUID).child("favourite").getData { [weak self] error, snapshot in
            guard error == nil else {
                completion(false, 54.0, 54.0)
                return
            }
            
            let chartPosts = snapshot.value as? [String] ?? []
            let isFavotite = chartPosts.contains(idPost)
            
            self?.reference.child("posts").child(idPost).getData { error, snapshot in
                guard error == nil else {
                    completion(isFavotite, 54.0, 54.0)
                    return
                }
                
                guard let postsData = snapshot.value as? [String : Any] else {
                    print("debug: postsData = snapshot.value")
                    completion(isFavotite, 54.0, 54.0)
                    return
                }
                
                let latitude: Double = postsData["latitude"] as? Double ?? 54.0
                let longitude: Double = postsData["longitude"] as? Double ?? 54.0
                
                completion(isFavotite, latitude, longitude)
            }
        }
    }
        
}

extension DatabaseManager {
    struct Constants {
        static let numberOfPostsBlock: Int = 5
        
    }
}
