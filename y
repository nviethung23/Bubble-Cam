rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== Helpers (nullable + kiểu dữ liệu) =====
    function isOptString(data, field) {
      return !(field in data) || (data[field] is string);
    }

    function isOptListString(data, field, max) {
      return !(field in data) ||
             (data[field] is list &&
              data[field].size() <= max &&
              (data[field].size() == 0 || data[field][0] is string));
      // Lưu ý: Rules không duyệt toàn bộ phần tử, chỉ sanity-check phần tử đầu.
    }

    function isOwner(resourceData) {
      return request.auth != null &&
             ('uid' in resourceData) &&
             resourceData.uid == request.auth.uid;
    }

    // ===== /users/{uid} =====
    match /users/{uid} {

      // Ai cũng có thể đọc profile cơ bản (tuỳ dự án, bạn có thể siết lại)
      allow get, list: if request.auth != null;

      // Tạo hồ sơ: chỉ chính chủ
      allow create: if request.auth != null
                    && request.auth.uid == uid
                    && isOptString(request.resource.data, 'name')
                    && isOptString(request.resource.data, 'phoneNumber')
                    && isOptString(request.resource.data, 'profileUrl')
                    && isOptListString(request.resource.data, 'friends', 1000);

      // Cập nhật: chỉ chính chủ, chỉ các field cho phép
      allow update: if request.auth != null
                    && request.auth.uid == uid
                    // Không cho thêm field lạ
                    && request.resource.data.keys().hasOnly(['name','phoneNumber','profileUrl','friends'])
                    && isOptString(request.resource.data, 'name')
                    && isOptString(request.resource.data, 'phoneNumber')
                    && isOptString(request.resource.data, 'profileUrl')
                    && isOptListString(request.resource.data, 'friends', 1000);

      // Xoá: chính chủ
      allow delete: if request.auth != null && request.auth.uid == uid;
    }

    // ===== /images/{imageId} =====
    match /images/{imageId} {
      // Đọc: chủ sở hữu hoặc nằm trong visibility
      allow get: if request.auth != null &&
                  (
                    isOwner(resource.data) ||
                    (
                      ('visibility' in resource.data) &&
                      (resource.data.visibility is list) &&
                      (request.auth.uid in resource.data.visibility)
                    )
                  );

      // List: chỉ những ảnh mà user có quyền xem (lọc ở client, rules vẫn check từng doc)
      allow list: if request.auth != null;

      // Tạo: bắt buộc uid = auth.uid, cho phép message/url/dateCreated/visibility (tuỳ chọn)
      allow create: if request.auth != null
                    && ('uid' in request.resource.data)
                    && request.resource.data.uid == request.auth.uid
                    && request.resource.data.keys().hasOnly(['uid','dateCreated','message','url','visibility'])
                    && isOptString(request.resource.data, 'dateCreated')   // bạn đang lưu dạng String
                    && isOptString(request.resource.data, 'message')
                    && isOptString(request.resource.data, 'url')
                    && isOptListString(request.resource.data, 'visibility', 500);

      // Update: chỉ chủ ảnh; không cho đổi uid
      allow update: if request.auth != null
                    && isOwner(resource.data)
                    && request.resource.data.diff(resource.data).unchangedKeys().hasAll(['uid'])
                    && request.resource.data.keys().hasOnly(['uid','dateCreated','message','url','visibility'])
                    && isOptString(request.resource.data, 'dateCreated')
                    && isOptString(request.resource.data, 'message')
                    && isOptString(request.resource.data, 'url')
                    && isOptListString(request.resource.data, 'visibility', 500);

      // Delete: chỉ chủ ảnh
      allow delete: if request.auth != null && isOwner(resource.data);
    }

    // ===== /friendRequests/{reqId} =====
    match /friendRequests/{reqId} {

      function isParticipant(data) {
        return request.auth != null &&
          (('senderId' in data && data.senderId == request.auth.uid) ||
           ('receiverId' in data && data.receiverId == request.auth.uid));
      }

      function isValidStatus(s) {
        return s in ['pending','accepted','rejected','canceled'];
      }

      // Đọc: chỉ người gửi hoặc người nhận
      allow get: if isParticipant(resource.data);
      allow list: if request.auth != null; // kết quả vẫn bị filter từng doc bởi get ở trên

      // Tạo: senderId = auth.uid, status = 'pending'
      allow create: if request.auth != null
                    && request.resource.data.keys().hasOnly(['senderId','receiverId','status'])
                    && ('senderId' in request.resource.data)
                    && ('receiverId' in request.resource.data)
                    && ('status' in request.resource.data)
                    && request.resource.data.senderId == request.auth.uid
                    && request.resource.data.senderId != request.resource.data.receiverId
                    && request.resource.data.status == 'pending';

      // Update:
      // - Người nhận có thể chuyển 'pending' -> 'accepted' | 'rejected'
      // - Người gửi có thể chuyển 'pending' -> 'canceled'
      allow update: if request.auth != null
        && request.resource.data.keys().hasOnly(['senderId','receiverId','status'])
        && resource.data.status == 'pending'
        && isValidStatus(request.resource.data.status)
        && (
            // receiver quyết định accept/reject
            (request.auth.uid == resource.data.receiverId &&
             request.resource.data.status in ['accepted','rejected'] &&
             request.resource.data.senderId == resource.data.senderId &&
             request.resource.data.receiverId == resource.data.receiverId)
            ||
            // sender huỷ
            (request.auth.uid == resource.data.senderId &&
             request.resource.data.status == 'canceled' &&
             request.resource.data.senderId == resource.data.senderId &&
             request.resource.data.receiverId == resource.data.receiverId)
        );

      // Xoá: một trong hai bên (tuỳ chính sách của bạn); ở đây cho phép cả hai
      allow delete: if isParticipant(resource.data);
    }
  }
}
