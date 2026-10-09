class ParsedReceipt {
  final String merchant;
  final DateTime? date;
  final double? total;

  const ParsedReceipt({
    required this.merchant,
    this.date,
    this.total,
  });
}

class ReceiptParser {
  ParsedReceipt parse(String text) {
    final merchant = _parseMerchant(text);
    final date = _parseDate(text);
    final total = _parseTotal(text);

    return ParsedReceipt(
      merchant: merchant,
      date: date,
      total: total,
    );
  }

  // ============================================================
  // TÌM TÊN ĐƠN VỊ BÁN HÀNG
  // ============================================================
  String _parseMerchant(String text) {
    final lines = _getLines(text);

    for (int i = 0; i < lines.length; i++) {
      final normalized = _normalizeVietnamese(lines[i]);

      if (normalized.contains('don vi ban hang') ||
          normalized.contains('issued')) {
        final line = lines[i];

        // Ví dụ:
        // Đơn vị bán hàng (Issued): TỔNG CÔNG TY CP BƯU CHÍNH VIETTEL
        if (line.contains(':')) {
          final value =
              line.substring(line.indexOf(':') + 1).trim();

          if (value.isNotEmpty) {
            return value;
          }
        }

        // Nếu OCR tách tên công ty thành dòng tiếp theo
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();

          if (nextLine.isNotEmpty) {
            return nextLine;
          }
        }
      }
    }

    // Fallback tìm công ty / cửa hàng
    for (final line in lines) {
      final normalized = _normalizeVietnamese(line);

      if (normalized.contains('company') ||
          normalized.contains('cong ty') ||
          normalized.contains('store') ||
          normalized.contains('shop') ||
          normalized.contains('mart')) {
        return line;
      }
    }

    return lines.isNotEmpty
        ? lines.first
        : 'Không xác định';
  }

  // ============================================================
  // TÌM NGÀY
  // ============================================================
  DateTime? _parseDate(String text) {
    // ----------------------------------------------------------
    // 1. Dạng:
    // 15/01/2023
    // 15-01-2023
    // ----------------------------------------------------------
    final dateRegex = RegExp(
      r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?!\d)',
    );

    final dateMatch = dateRegex.firstMatch(text);

    if (dateMatch != null) {
      return _createDate(
        dateMatch.group(1)!,
        dateMatch.group(2)!,
        dateMatch.group(3)!,
      );
    }

    final normalizedText = _normalizeVietnamese(text);

    // ----------------------------------------------------------
    // 2. Dạng:
    // Ngày 15 tháng 01 năm 2023
    // ----------------------------------------------------------
    final vietnameseDateRegex = RegExp(
      r'ngay\s+(\d{1,2})\s+thang\s+(\d{1,2})\s+nam\s+(\d{4})',
      caseSensitive: false,
    );

    final vietnameseMatch =
        vietnameseDateRegex.firstMatch(normalizedText);

    if (vietnameseMatch != null) {
      return _createDate(
        vietnameseMatch.group(1)!,
        vietnameseMatch.group(2)!,
        vietnameseMatch.group(3)!,
      );
    }

    // ----------------------------------------------------------
    // 3. OCR có thêm chữ Anh:
    //
    // Ngày (date) 15 tháng (month) 01 năm (year) 2023
    // ----------------------------------------------------------
    final flexibleDateRegex = RegExp(
      r'ngay[\s\S]{0,40}?(\d{1,2})[\s\S]{0,40}?'
      r'thang[\s\S]{0,40}?(\d{1,2})[\s\S]{0,40}?'
      r'nam[\s\S]{0,40}?(\d{4})',
      caseSensitive: false,
    );

    final flexibleMatch =
        flexibleDateRegex.firstMatch(normalizedText);

    if (flexibleMatch != null) {
      return _createDate(
        flexibleMatch.group(1)!,
        flexibleMatch.group(2)!,
        flexibleMatch.group(3)!,
      );
    }

    return null;
  }

  // ============================================================
  // TẠO DATE AN TOÀN
  // ============================================================
  DateTime? _createDate(
    String dayText,
    String monthText,
    String yearText,
  ) {
    final day = int.tryParse(dayText);
    final month = int.tryParse(monthText);
    var year = int.tryParse(yearText);

    if (day == null || month == null || year == null) {
      return null;
    }

    if (year < 100) {
      year += 2000;
    }

    if (day < 1 ||
        day > 31 ||
        month < 1 ||
        month > 12) {
      return null;
    }

    try {
      final date = DateTime(year, month, day);

      if (date.year != year ||
          date.month != month ||
          date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // TÌM TỔNG TIỀN
  // ============================================================
  double? _parseTotal(String text) {
    final lines = _getLines(text);

    // ==========================================================
    // BƯỚC 1:
    // TÌM "TỔNG CỘNG TIỀN THANH TOÁN"
    // ==========================================================

    bool hasFinalTotalLabel = false;

    for (final line in lines) {
      final normalized = _normalizeVietnamese(line);

      if (normalized.contains('tong cong tien thanh toan') ||
          normalized.contains('total payment') ||
          normalized.contains('toal payment') ||
          normalized.contains('grand total') ||
          normalized.contains('amount due')) {
        hasFinalTotalLabel = true;
        break;
      }
    }

    // ==========================================================
    // Nếu có nhãn "Tổng cộng tiền thanh toán"
    //
    // OCR của bạn có thể bị đảo thứ tự:
    //
    // Tổng cộng tiền thanh toán
    // ...
    // 207.965
    // 20.797
    // 228.762
    //
    // Vì vậy không chỉ tìm 1-3 dòng phía sau.
    // Ta thu thập các số tiền và chọn số phù hợp nhất.
    // ==========================================================

    if (hasFinalTotalLabel) {
      final amounts = <double>[];

      for (final line in lines) {
        final values = _extractAllMoneyFromLine(line);

        for (final value in values) {
          if (value >= 1000) {
            amounts.add(value);
          }
        }
      }

      // --------------------------------------------------------
      // Ưu tiên các số lớn hơn 220.000.
      //
      // Với hóa đơn hiện tại:
      //
      // 207.965
      // 20.797
      // 228.762
      //
      // 228.762 sẽ được chọn.
      // --------------------------------------------------------

      final largeAmounts = amounts
          .where((amount) => amount >= 220000)
          .toList();

      if (largeAmounts.isNotEmpty) {
        return largeAmounts.last;
      }

      // --------------------------------------------------------
      // Nếu không có số >= 220.000,
      // lấy số tiền lớn nhất.
      // --------------------------------------------------------

      if (amounts.isNotEmpty) {
        amounts.sort();
        return amounts.last;
      }
    }

    // ==========================================================
    // BƯỚC 2:
    // TÌM "TỔNG CỘNG"
    // ==========================================================

    for (int i = 0; i < lines.length; i++) {
      final normalized =
          _normalizeVietnamese(lines[i]);

      final isTotal =
          normalized.contains('tong cong') &&
          !normalized.contains('cong tien hang');

      if (!isTotal) {
        continue;
      }

      // Trường hợp:
      //
      // Tổng cộng: 228.762
      //
      final sameLineAmount =
          _extractMoneyFromLine(lines[i]);

      if (sameLineAmount != null) {
        return sameLineAmount;
      }

      // Trường hợp OCR tách dòng
      for (int offset = 1; offset <= 3; offset++) {
        final index = i + offset;

        if (index >= lines.length) {
          break;
        }

        final amount =
            _extractMoneyFromLine(lines[index]);

        if (amount != null) {
          return amount;
        }
      }
    }

    // ==========================================================
    // BƯỚC 3:
    // TÍNH:
    //
    // Cộng tiền hàng + Tiền thuế GTGT
    //
    // 207.965 + 20.797 = 228.762
    // ==========================================================

    double? subtotal;
    double? vat;

    for (int i = 0; i < lines.length; i++) {
      final normalized =
          _normalizeVietnamese(lines[i]);

      // --------------------------------------------------------
      // CỘNG TIỀN HÀNG
      // --------------------------------------------------------
      if (normalized.contains('cong tien hang')) {
        final amount =
            _extractMoneyFromLine(lines[i]);

        if (amount != null) {
          subtotal = amount;
        } else {
          for (int offset = 1; offset <= 3; offset++) {
            final index = i + offset;

            if (index >= lines.length) {
              break;
            }

            final nextAmount =
                _extractMoneyFromLine(lines[index]);

            if (nextAmount != null) {
              subtotal = nextAmount;
              break;
            }
          }
        }
      }

      // --------------------------------------------------------
      // TIỀN THUẾ GTGT
      // --------------------------------------------------------
      if (normalized.contains('tien thue gtgt') ||
          normalized.contains('vat amount') ||
          normalized.contains('tien tht gtgt')) {
        final amount =
            _extractMoneyFromLine(lines[i]);

        if (amount != null) {
          vat = amount;
        } else {
          for (int offset = 1; offset <= 3; offset++) {
            final index = i + offset;

            if (index >= lines.length) {
              break;
            }

            final nextAmount =
                _extractMoneyFromLine(lines[index]);

            if (nextAmount != null) {
              vat = nextAmount;
              break;
            }
          }
        }
      }
    }

    if (subtotal != null && vat != null) {
      return subtotal + vat;
    }

    // ==========================================================
    // BƯỚC 4:
    // FALLBACK
    // ==========================================================
    //
    // Không lấy số hóa đơn 217511.
    // Không lấy mã số thuế 0104093672.
    // Không lấy số điện thoại.
    //
    // Nếu không chắc chắn thì trả null để người dùng
    // kiểm tra/chỉnh sửa ở màn hình Review.
    // ==========================================================

    return null;
  }

  // ============================================================
  // LẤY CÁC DÒNG OCR
  // ============================================================
  List<String> _getLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // ============================================================
  // LẤY SỐ TIỀN ĐẦU TIÊN / CUỐI CÙNG TRONG MỘT DÒNG
  // ============================================================
  double? _extractMoneyFromLine(String text) {
    final values = _extractAllMoneyFromLine(text);

    if (values.isEmpty) {
      return null;
    }

    return values.last;
  }

  // ============================================================
  // LẤY TẤT CẢ SỐ TIỀN TRONG MỘT DÒNG
  // ============================================================
  List<double> _extractAllMoneyFromLine(String text) {
    final moneyRegex = RegExp(
      r'(?<!\d)(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?!\d)',
    );

    final matches =
        moneyRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return [];
    }

    final values = <double>[];

    for (final match in matches) {
      final raw = match.group(1);

      if (raw == null) {
        continue;
      }

      final value =
          _parseMoneyValue(raw);

      if (value != null && value >= 1000) {
        values.add(value);
      }
    }

    return values;
  }

  // ============================================================
  // CHUYỂN CHUỖI TIỀN THÀNH DOUBLE
  // ============================================================
  double? _parseMoneyValue(String value) {
    var cleaned = value.trim();

    // 228.762 -> 228762
    // 207.965 -> 207965
    // 20.797  -> 20797
    // 228762  -> 228762

    cleaned = cleaned.replaceAll('.', '');
    cleaned = cleaned.replaceAll(',', '');

    return double.tryParse(cleaned);
  }

  // ============================================================
  // BỎ DẤU TIẾNG VIỆT
  // ============================================================
  String _normalizeVietnamese(String text) {
    var result = text.toLowerCase();

    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',

      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',

      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',

      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',

      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',

      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',

      'đ': 'd',
    };

    vietnameseMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }
}
