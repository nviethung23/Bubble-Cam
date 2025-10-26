class PhoneHelper {
  /// Chuẩn hóa SĐT về dạng +84...
  /// VD: 0584222383 → +84584222383
  ///     +84584222383 → +84584222383
  ///     84584222383 → +84584222383
  static String normalize(String phone, {String countryCode = '+84'}) {
    // Xóa khoảng trắng, dấu gạch ngang, dấu ngoặc, dấu chấm
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    
    // Nếu rỗng
    if (phone.isEmpty) return '';
    
    // Nếu bắt đầu bằng 0 → thay bằng countryCode
    if (phone.startsWith('0')) {
      return '$countryCode${phone.substring(1)}';
    }
    
    // Nếu bắt đầu bằng 84 (không có +) → thêm +
    if (phone.startsWith('84') && !phone.startsWith('+84')) {
      return '+$phone';
    }
    
    // Nếu đã có +84
    if (phone.startsWith('+84')) {
      return phone;
    }
    
    // Nếu là số khác quốc gia (VD: +1, +65...)
    if (phone.startsWith('+')) {
      return phone;
    }
    
    // Mặc định thêm countryCode
    return '$countryCode$phone';
  }
  
  /// ✅ Alias cho normalize (tương thích với code cũ)
  static String normalizePhoneNumber(String phoneNumber, {String countryCode = '+84'}) {
    return normalize(phoneNumber, countryCode: countryCode);
  }
  
  /// Kiểm tra 2 SĐT có giống nhau không (sau khi normalize)
  static bool isSame(String phone1, String phone2) {
    return normalize(phone1) == normalize(phone2);
  }
  
  /// Format hiển thị: +84584222383 → 0584 222 383
  static String format(String phone) {
    phone = normalize(phone);
    
    if (phone.startsWith('+84')) {
      String body = phone.substring(3); // Bỏ +84
      
      // VD: 584222383 → 0584 222 383
      if (body.length >= 9) {
        return '0${body.substring(0, 3)} ${body.substring(3, 6)} ${body.substring(6)}';
      }
      
      // Nếu ngắn hơn 9 số
      if (body.length >= 6) {
        return '0${body.substring(0, 3)} ${body.substring(3)}';
      }
      
      return '0$body';
    }
    
    // Số nước ngoài hoặc chưa chuẩn hóa
    return phone;
  }
  
  /// ✅ Alias cho format (tương thích với code cũ)
  static String formatForDisplay(String phoneNumber) {
    return format(phoneNumber);
  }
  
  /// Validate SĐT Việt Nam
  static bool isValidVietnamesePhone(String phone) {
    phone = normalize(phone);
    
    // Phải bắt đầu bằng +84
    if (!phone.startsWith('+84')) return false;
    
    // Phải có 12 ký tự (+84 + 9 số)
    if (phone.length != 12) return false;
    
    // Số sau +84 phải là số hợp lệ (3, 5, 7, 8, 9)
    final firstDigit = phone[3];
    if (!['3', '5', '7', '8', '9'].contains(firstDigit)) return false;
    
    return true;
  }
  
  /// Lấy đầu số (VD: +84584222383 → 058)
  static String getPrefix(String phone) {
    phone = normalize(phone);
    
    if (phone.startsWith('+84') && phone.length >= 6) {
      return '0${phone.substring(3, 6)}';
    }
    
    return '';
  }
  
  /// Ẩn số giữa (VD: +84584222383 → 0584***383)
  static String maskPhone(String phone) {
    phone = normalize(phone);
    
    if (phone.startsWith('+84') && phone.length == 12) {
      String body = phone.substring(3);
      return '0${body.substring(0, 3)}***${body.substring(6)}';
    }
    
    return phone;
  }
}

// ✅ Alias class để tương thích với code cũ
class PhoneUtils {
  static String normalizePhoneNumber(String phoneNumber, {String countryCode = '+84'}) {
    return PhoneHelper.normalize(phoneNumber, countryCode: countryCode);
  }
  
  static String formatForDisplay(String phoneNumber) {
    return PhoneHelper.format(phoneNumber);
  }
}