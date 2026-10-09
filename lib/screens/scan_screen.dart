import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final ReceiptParser _receiptParser = ReceiptParser();

  bool _isProcessing = false;
  bool _isSaving = false;

  String _ocrText = '';

  String _merchant = '';
  String _date = '';
  String _total = '';
  String _category = 'Khác';

  File? _selectedImage;

  // ============================================================
  // CHỌN ẢNH TỪ CAMERA
  // ============================================================
  Future<void> _pickFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);

      _ocrText = '';
      _merchant = '';
      _date = '';
      _total = '';
      _category = 'Khác';
    });
  }

  // ============================================================
  // CHỌN ẢNH TỪ THƯ VIỆN
  // ============================================================
  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);

      _ocrText = '';
      _merchant = '';
      _date = '';
      _total = '';
      _category = 'Khác';
    });
  }

  // ============================================================
  // FALLBACK NHẬN DIỆN TIỀN TỪ OCR
  //
  // Dùng khi ReceiptParser không nhận được tổng tiền.
  //
  // Hỗ trợ:
  // 230000 VND
  // 230000VND
  // 230.000 VND
  // 230,000 VND
  // 230000 đ
  // 230.000đ
  // ============================================================
  double? _extractMoneyFromOcr(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final normalized = text
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '');

    // ----------------------------------------------------------
    // 1. Ưu tiên số tiền đi kèm VND / VNĐ / đ / đồng
    // ----------------------------------------------------------
    final moneyRegex = RegExp(
      r'(?<!\d)(\d{1,3}(?:[., ]\d{3})+|\d{4,})\s*(?:VND|VNĐ|đ|Đ|dong|đồng)\b',
      caseSensitive: false,
    );

    final moneyMatches = moneyRegex.allMatches(normalized);

    final moneyValues = <double>[];

    for (final match in moneyMatches) {
      final raw = match.group(1);

      if (raw == null) {
        continue;
      }

      final parsed = _parseMoneyString(raw);

      if (parsed != null && parsed > 0) {
        moneyValues.add(parsed);
      }
    }

    if (moneyValues.isNotEmpty) {
      // Nếu có nhiều số tiền kèm VND/đ,
      // ưu tiên số lớn nhất vì thường là tổng thanh toán.
      return moneyValues.reduce(
        (a, b) => a > b ? a : b,
      );
    }

    // ----------------------------------------------------------
    // 2. Tìm số tiền sau các từ khóa tổng tiền
    // ----------------------------------------------------------
    final totalRegex = RegExp(
      r'(?:total|grand\s*total|amount\s*due|'
      r'total\s*payment|toal\s*payment|'
      r'tổng\s*cộng|tong\s*cong|'
      r'tổng\s*tiền|tong\s*tien)'
      r'[^0-9]{0,30}'
      r'(\d{1,3}(?:[., ]\d{3})+|\d{4,})',
      caseSensitive: false,
    );

    final totalMatches = totalRegex.allMatches(normalized);

    final totalValues = <double>[];

    for (final match in totalMatches) {
      final raw = match.group(1);

      if (raw == null) {
        continue;
      }

      final parsed = _parseMoneyString(raw);

      if (parsed != null && parsed > 0) {
        totalValues.add(parsed);
      }
    }

    if (totalValues.isNotEmpty) {
      return totalValues.reduce(
        (a, b) => a > b ? a : b,
      );
    }

    return null;
  }

  // ============================================================
  // CHUYỂN CHUỖI TIỀN THÀNH DOUBLE
  //
  // Ví dụ:
  // 230000     -> 230000
  // 230.000    -> 230000
  // 230,000    -> 230000
  // 230 000    -> 230000
  // ============================================================
  double? _parseMoneyString(String value) {
    var cleaned = value.trim();

    if (cleaned.isEmpty) {
      return null;
    }

    // Bỏ khoảng trắng giữa các nhóm số
    cleaned = cleaned.replaceAll(' ', '');

    // Nếu có cả . và ,
    if (cleaned.contains('.') &&
        cleaned.contains(',')) {
      // Ví dụ: 230.000,50
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');

      if (lastComma > lastDot) {
        cleaned = cleaned
            .replaceAll('.', '')
            .replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else {
      // Với tiền Việt:
      // 230.000 -> 230000
      // 230,000 -> 230000
      // 230000 -> 230000
      cleaned = cleaned
          .replaceAll('.', '')
          .replaceAll(',', '');
    }

    return double.tryParse(cleaned);
  }

  // ============================================================
  // OCR + PARSER
  // ============================================================
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _ocrText = '';
      _merchant = '';
      _date = '';
      _total = '';
    });

    try {
      // OCR
      final text = await _ocrService.recognizeText(
        _selectedImage!.path,
      );

      // Parser
      final result = _receiptParser.parse(text);

      // --------------------------------------------------------
      // Format ngày
      // --------------------------------------------------------
      String formattedDate = 'Chưa nhận diện';

      if (result.date != null) {
        formattedDate =
            '${result.date!.day.toString().padLeft(2, '0')}/'
            '${result.date!.month.toString().padLeft(2, '0')}/'
            '${result.date!.year}';
      }

      // --------------------------------------------------------
      // Format tiền
      // --------------------------------------------------------
      double? detectedTotal = result.total;

      // Nếu ReceiptParser không nhận được tiền,
      // thử fallback trực tiếp từ OCR.
      if (detectedTotal == null) {
        detectedTotal = _extractMoneyFromOcr(text);

        if (detectedTotal != null) {
          debugPrint(
            'Fallback OCR total: $detectedTotal',
          );
        }
      }

      String formattedTotal = 'Chưa nhận diện';

      if (detectedTotal != null) {
        formattedTotal = _formatMoney(
          detectedTotal,
        );
      }

      debugPrint(
        '========== PARSED RECEIPT ==========',
      );
      debugPrint(
        'Merchant: ${result.merchant}',
      );
      debugPrint(
        'Date: $formattedDate',
      );
      debugPrint(
        'Total: $formattedTotal',
      );
      debugPrint(
        '====================================',
      );

      if (!mounted) return;

      setState(() {
        _ocrText = text;

        _merchant = result.merchant.isNotEmpty
            ? result.merchant
            : 'Chưa nhận diện';

        _date = formattedDate;
        _total = formattedTotal;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể đọc hóa đơn.\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT TIỀN
  // ============================================================
  String _formatMoney(double amount) {
    final value = amount.round().toString();

    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 &&
          (value.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(value[i]);
    }

    return '${buffer.toString()} đ';
  }

  // ============================================================
  // CHUYỂN TIỀN TỪ STRING -> DOUBLE
  // ============================================================
  double? _parseTotal() {
    if (_total.isEmpty ||
        _total == 'Chưa nhận diện' ||
        _total == 'Chưa nhập') {
      return null;
    }

    final cleaned = _total
        .replaceAll('VND', '')
        .replaceAll('VNĐ', '')
        .replaceAll('vnd', '')
        .replaceAll('vnđ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('đ', '')
        .replaceAll('Đ', '')
        .trim();

    return double.tryParse(cleaned);
  }

  // ============================================================
  // CHUYỂN NGÀY dd/MM/yyyy -> DateTime
  // ============================================================
  DateTime? _parseDate() {
    if (_date.isEmpty ||
        _date == 'Chưa nhận diện' ||
        _date == 'Chưa nhập') {
      return null;
    }

    final parts = _date.split('/');

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null ||
        month == null ||
        year == null) {
      return null;
    }

    try {
      final date = DateTime(
        year,
        month,
        day,
      );

      // Kiểm tra ngày hợp lệ
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
  // CHỈNH SỬA THÔNG TIN
  // ============================================================
  Future<void> _editReceipt() async {
    final merchantController =
        TextEditingController(
      text: _merchant == 'Chưa nhận diện'
          ? ''
          : _merchant,
    );

    final dateController =
        TextEditingController(
      text: _date == 'Chưa nhận diện'
          ? ''
          : _date,
    );

    final totalController =
        TextEditingController(
      text: _total
          .replaceAll('VND', '')
          .replaceAll('VNĐ', '')
          .replaceAll('vnd', '')
          .replaceAll('vnđ', '')
          .replaceAll('.', '')
          .replaceAll(',', '')
          .replaceAll(' đ', '')
          .replaceAll('đ', '')
          .trim(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Chỉnh sửa hóa đơn',
          ),
          content:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextField(
                  controller:
                      merchantController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Cửa hàng / Đơn vị',
                    prefixIcon: Icon(
                      Icons.store_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller:
                      dateController,
                  keyboardType:
                      TextInputType.datetime,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Ngày giao dịch',
                    hintText:
                        'dd/MM/yyyy',
                    prefixIcon: Icon(
                      Icons
                          .calendar_today_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller:
                      totalController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Tổng tiền',
                    suffixText: 'đ',
                    prefixIcon: Icon(
                      Icons
                          .payments_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Hủy'),
            ),

            FilledButton(
              onPressed: () {
                setState(() {
                  _merchant =
                      merchantController
                              .text
                              .trim()
                              .isEmpty
                          ? 'Chưa nhập'
                          : merchantController
                              .text
                              .trim();

                  _date =
                      dateController.text
                              .trim()
                              .isEmpty
                          ? 'Chưa nhập'
                          : dateController
                              .text
                              .trim();

                  final money =
                      totalController.text
                          .trim();

                  if (money.isEmpty) {
                    _total =
                        'Chưa nhập';
                  } else {
                    final parsed =
                        _parseMoneyString(
                      money,
                    );

                    if (parsed != null) {
                      _total =
                          _formatMoney(
                        parsed,
                      );
                    } else {
                      _total =
                          '$money đ';
                    }
                  }
                });

                Navigator.pop(context);
              },
              child: const Text(
                'Lưu thay đổi',
              ),
            ),
          ],
        );
      },
    );

    merchantController.dispose();
    dateController.dispose();
    totalController.dispose();
  }

  // ============================================================
  // LƯU KHOẢN CHI VÀO SQLITE
  // ============================================================
  Future<void> _saveExpense() async {
    // Kiểm tra tên cửa hàng
    if (_merchant.isEmpty ||
        _merchant == 'Chưa nhận diện' ||
        _merchant == 'Chưa nhập') {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập tên cửa hàng / đơn vị.',
          ),
        ),
      );
      return;
    }

    // Kiểm tra tổng tiền
    final amount = _parseTotal();

    if (amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng kiểm tra và nhập tổng tiền hợp lệ.',
          ),
        ),
      );
      return;
    }

    // Kiểm tra ngày
    final date = _parseDate();

    if (date == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập ngày theo dạng dd/MM/yyyy.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final expense = Expense(
        merchant: _merchant,
        amount: amount,
        date: date,
        category: _category,
        imagePath: _selectedImage?.path,
      );

      await ref
          .read(
            expenseProvider.notifier,
          )
          .addExpense(expense);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu khoản chi thành công!',
          ),
        ),
      );

      // Quay lại HomeScreen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Không thể lưu khoản chi.\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final hasResult =
        !_isProcessing &&
        _ocrText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quét biên nhận',
        ),
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // ẢNH HÓA ĐƠN
            // ==================================================
            Container(
              width: double.infinity,
              height: 300,

              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                color: colorScheme
                    .surfaceContainerHighest,
              ),

              child:
                  _selectedImage == null
                      ? Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons
                                  .receipt_long_outlined,
                              size: 72,
                              color:
                                  colorScheme
                                      .primary,
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            Text(
                              'Chọn hoặc chụp hóa đơn',
                              style: theme
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Text(
                              'Ảnh hóa đơn sẽ được phân tích bằng OCR',
                              textAlign:
                                  TextAlign
                                      .center,
                              style: theme
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          child:
                              Image.file(
                            _selectedImage!,
                            width:
                                double.infinity,
                            height:
                                double.infinity,
                            fit: BoxFit
                                .contain,
                          ),
                        ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // CHỤP HÓA ĐƠN
            // ==================================================
            SizedBox(
              width:
                  double.infinity,
              height: 52,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _isProcessing ||
                            _isSaving
                        ? null
                        : _pickFromCamera,

                icon: const Icon(
                  Icons
                      .camera_alt_outlined,
                ),

                label: const Text(
                  'Chụp hóa đơn',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // CHỌN THƯ VIỆN
            // ==================================================
            SizedBox(
              width:
                  double.infinity,
              height: 52,

              child:
                  OutlinedButton.icon(
                onPressed:
                    _isProcessing ||
                            _isSaving
                        ? null
                        : _pickFromGallery,

                icon: const Icon(
                  Icons
                      .photo_library_outlined,
                ),

                label: const Text(
                  'Chọn từ thư viện',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // ==================================================
            // ĐỌC HÓA ĐƠN
            // ==================================================
            if (_selectedImage !=
                null) ...[
              const SizedBox(
                height: 12,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 52,

                child:
                    FilledButton.icon(
                  onPressed:
                      _isProcessing ||
                              _isSaving
                          ? null
                          : _processImage,

                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .document_scanner_outlined,
                        ),

                  label: Text(
                    _isProcessing
                        ? 'Đang đọc hóa đơn...'
                        : 'Đọc hóa đơn',

                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],

            // ==================================================
            // LOADING
            // ==================================================
            if (_isProcessing) ...[
              const SizedBox(
                height: 24,
              ),

              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color:
                          colorScheme
                              .primary,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Đang nhận diện nội dung hóa đơn...',
                      style: theme
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // KẾT QUẢ
            // ==================================================
            if (hasResult) ...[
              const SizedBox(
                height: 28,
              ),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thông tin hóa đơn',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip:
                        'Chỉnh sửa',
                    onPressed:
                        _isSaving
                            ? null
                            : _editReceipt,
                    icon: const Icon(
                      Icons
                          .edit_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // CARD THÔNG TIN
              // ==================================================
              Card(
                elevation: 0,
                color: colorScheme
                    .surfaceContainerHighest,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                ),

                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    8,
                  ),

                  child:
                      Column(
                    children: [
                      // CỬA HÀNG
                      ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              colorScheme
                                  .primaryContainer,
                          child: Icon(
                            Icons
                                .store_outlined,
                            color: colorScheme
                                .onPrimaryContainer,
                          ),
                        ),

                        title:
                            const Text(
                          'Cửa hàng / Đơn vị',
                        ),

                        subtitle:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                          ),

                          child:
                              Text(
                            _merchant,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const Divider(
                        height: 1,
                      ),

                      // NGÀY
                      ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              colorScheme
                                  .secondaryContainer,
                          child: Icon(
                            Icons
                                .calendar_today_outlined,
                            color: colorScheme
                                .onSecondaryContainer,
                          ),
                        ),

                        title:
                            const Text(
                          'Ngày giao dịch',
                        ),

                        subtitle:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                          ),

                          child:
                              Text(
                            _date,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const Divider(
                        height: 1,
                      ),

                      // TỔNG TIỀN
                      ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              colorScheme
                                  .tertiaryContainer,
                          child: Icon(
                            Icons
                                .payments_outlined,
                            color: colorScheme
                                .onTertiaryContainer,
                          ),
                        ),

                        title:
                            const Text(
                          'Tổng tiền',
                        ),

                        subtitle:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                          ),

                          child:
                              Text(
                            _total,
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 20,
                              color:
                                  colorScheme
                                      .primary,
                            ),
                          ),
                        ),
                      ),

                      const Divider(
                        height: 1,
                      ),

                      // DANH MỤC
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),

                        child:
                            DropdownButtonFormField<
                                String>(
                          initialValue:
                              _category,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'Danh mục',

                            prefixIcon:
                                Icon(
                              Icons
                                  .category_outlined,
                            ),

                            border:
                                OutlineInputBorder(),
                          ),

                          items: const [
                            DropdownMenuItem(
                              value:
                                  'Ăn uống',
                              child:
                                  Text(
                                'Ăn uống',
                              ),
                            ),

                            DropdownMenuItem(
                              value:
                                  'Mua sắm',
                              child:
                                  Text(
                                'Mua sắm',
                              ),
                            ),

                            DropdownMenuItem(
                              value:
                                  'Di chuyển',
                              child:
                                  Text(
                                'Di chuyển',
                              ),
                            ),

                            DropdownMenuItem(
                              value:
                                  'Hóa đơn',
                              child:
                                  Text(
                                'Hóa đơn',
                              ),
                            ),

                            DropdownMenuItem(
                              value:
                                  'Khác',
                              child:
                                  Text(
                                'Khác',
                              ),
                            ),
                          ],

                          onChanged:
                              _isSaving
                                  ? null
                                  : (value) {
                                      if (value ==
                                          null) {
                                        return;
                                      }

                                      setState(
                                        () {
                                          _category =
                                              value;
                                        },
                                      );
                                    },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // OCR GỐC
              // ==================================================
              const SizedBox(
                height: 28,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        Text(
                      'Nội dung OCR',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),

                  Icon(
                    Icons
                        .text_snippet_outlined,
                    color:
                        colorScheme
                            .primary,
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Nội dung được nhận dạng trực tiếp từ hình ảnh',
                style: theme
                    .textTheme
                    .bodySmall,
              ),

              const SizedBox(
                height: 12,
              ),

              Container(
                width:
                    double.infinity,

                constraints:
                    const BoxConstraints(
                  maxHeight: 400,
                ),

                padding:
                    const EdgeInsets.all(
                  16,
                ),

                decoration:
                    BoxDecoration(
                  color: colorScheme
                      .surfaceContainerHighest,

                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),

                  border: Border.all(
                    color: colorScheme
                        .outlineVariant,
                  ),
                ),

                child:
                    SingleChildScrollView(
                  child:
                      SelectableText(
                    _ocrText,

                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // NÚT CHỈNH SỬA
              // ==================================================
              SizedBox(
                width:
                    double.infinity,
                height: 50,

                child:
                    OutlinedButton.icon(
                  onPressed:
                      _isSaving
                          ? null
                          : _editReceipt,

                  icon: const Icon(
                    Icons
                        .edit_outlined,
                  ),

                  label: const Text(
                    'Kiểm tra và chỉnh sửa thông tin',
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // NÚT LƯU KHOẢN CHI
              // ==================================================
              SizedBox(
                width:
                    double.infinity,
                height: 54,

                child:
                    FilledButton.icon(
                  onPressed:
                      _isSaving
                          ? null
                          : _saveExpense,

                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .save_outlined,
                        ),

                  label: Text(
                    _isSaving
                        ? 'Đang lưu...'
                        : 'Lưu khoản chi',

                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // GHI CHÚ
              // ==================================================
              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(
                  14,
                ),

                decoration:
                    BoxDecoration(
                  color: colorScheme
                      .primaryContainer
                      .withValues(
                    alpha: 0.5,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child:
                    Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Icon(
                      Icons
                          .info_outline,
                      color:
                          colorScheme
                              .primary,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          Text(
                        'OCR có thể nhận diện sai một số ký tự '
                        'hoặc số tiền. Hãy kiểm tra và chỉnh sửa '
                        'thông tin trước khi lưu.',

                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Khoảng trống cuối trang
              const SizedBox(
                height: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
