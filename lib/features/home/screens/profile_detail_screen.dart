import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../core/widgets/user_avatar.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedGender = 'Nam';
  int _selectedBirthYear = 1995;
  String _targetBedtime = '23:00';
  String _targetWakeTime = '07:00';
  String _activityLevel = 'Vừa phải (3-5 ngày/tuần)';
  bool _isEditing = false;
  bool _isAvatarLoading = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _heightController.text = user.heightCm?.toStringAsFixed(0) ?? '';
      _weightController.text = user.weightKg?.toStringAsFixed(1) ?? '';
      _selectedGender = user.gender ?? 'Nam';
      _selectedBirthYear = user.birthYear ?? 1995;
      _targetBedtime = user.targetBedtime;
      _targetWakeTime = user.targetWakeTime;

      final rawLevel = user.activityLevel;
      if (rawLevel == 'Không' || rawLevel == 'Không tập luyện') {
        _activityLevel = 'Không tập luyện';
      } else if (rawLevel == 'Ít' || rawLevel == 'Ít (1-2 ngày/tuần)') {
        _activityLevel = 'Ít (1-2 ngày/tuần)';
      } else if (rawLevel == 'Nhiều' || rawLevel == 'Nhiều (6-7 ngày/tuần)') {
        _activityLevel = 'Nhiều (6-7 ngày/tuần)';
      } else {
        _activityLevel = 'Vừa phải (3-5 ngày/tuần)';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final height = double.tryParse(_heightController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;

    if (name.isEmpty || height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ và đúng thông tin.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name: name,
      birthYear: _selectedBirthYear,
      gender: _selectedGender,
      heightCm: height,
      weightKg: weight,
      targetBedtime: _targetBedtime,
      targetWakeTime: _targetWakeTime,
      activityLevel: _activityLevel,
    );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ cá nhân thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Không thể lưu thay đổi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Tính chỉ số BMI
    double bmi = 0;
    String bmiCategory = 'Chưa có dữ liệu';
    Color bmiColor = Colors.grey;
    String bmiAdvice = '';

    if (user.heightCm != null && user.weightKg != null && user.heightCm! > 0) {
      final heightM = user.heightCm! / 100;
      bmi = user.weightKg! / (heightM * heightM);
      if (bmi < 18.5) {
        bmiCategory = 'Gầy (Dưới chuẩn)';
        bmiColor = Colors.orange;
        bmiAdvice = 'Bạn nên bổ sung thêm dinh dưỡng và tập thể hình để tăng cơ.';
      } else if (bmi < 24.9) {
        bmiCategory = 'Bình thường (Lý tưởng)';
        bmiColor = AppColors.primary;
        bmiAdvice = 'Tuyệt vời! Hãy tiếp tục duy trì chế độ ăn và luyện tập hiện tại.';
      } else if (bmi < 29.9) {
        bmiCategory = 'Thừa cân';
        bmiColor = Colors.orangeAccent;
        bmiAdvice = 'Bạn nên tăng cường vận động và hạn chế thức ăn nhanh, chất béo.';
      } else {
        bmiCategory = 'Béo phì';
        bmiColor = AppColors.error;
        bmiAdvice = 'Cảnh báo! Bạn cần thiết lập chế độ giảm cân khoa học và tập thể dục đều đặn.';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Chỉnh sửa hồ sơ' : 'Hồ sơ cá nhân',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (_isEditing) {
              setState(() {
                _isEditing = false;
                _initFields(); // Khôi phục dữ liệu ban đầu
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header Info Card ───
              _buildHeaderCard(user),
              const SizedBox(height: 24),

              if (!_isEditing) ...[
                // ─── VIEW MODE ───
                _buildMetricsGrid(user),
                _buildSleepTargetsSection(user),
                _buildActivityLevelSection(user),
                const SizedBox(height: 24),
                _buildBmiCard(bmi, bmiCategory, bmiColor, bmiAdvice),
              ] else ...[
                // ─── EDIT MODE ───
                _buildEditForm(),
                const SizedBox(height: 32),
                _buildActionButtons(auth.isLoading),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(dynamic user) {
    final auth = context.read<AuthProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isAvatarLoading ? null : () => _showAvatarPicker(context, auth),
            child: Stack(
              children: [
                UserAvatar(
                  avatarUrl: user.avatarUrl,
                  size: 68,
                  borderRadius: 34,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                if (_isAvatarLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext parentContext, AuthProvider auth) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _AvatarPickerSheet(
          currentAvatarUrl: auth.currentUser?.avatarUrl,
          onAvatarSelected: (newUrl) async {
            Navigator.of(sheetContext).pop();
            
            setState(() {
              _isAvatarLoading = true;
            });

            final success = await auth.updateAvatar(newUrl);

            if (parentContext.mounted && mounted) {
              setState(() {
                _isAvatarLoading = false;
              });
              
              if (success) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Cập nhật ảnh đại diện thành công!'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(auth.errorMessage ?? 'Không thể cập nhật ảnh đại diện.'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildMetricsGrid(dynamic user) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricTile(
          icon: Icons.face_rounded,
          label: 'Giới tính',
          value: user.gender ?? 'Chưa rõ',
          color: Colors.purple,
        ),
        _buildMetricTile(
          icon: Icons.calendar_month_rounded,
          label: 'Năm sinh',
          value: user.birthYear?.toString() ?? 'Chưa rõ',
          color: Colors.blue,
        ),
        _buildMetricTile(
          icon: Icons.height_rounded,
          label: 'Chiều cao',
          value: user.heightCm != null ? '${user.heightCm!.toStringAsFixed(0)} cm' : 'Chưa rõ',
          color: AppColors.primary,
        ),
        _buildMetricTile(
          icon: Icons.monitor_weight_outlined,
          label: 'Cân nặng',
          value: user.weightKg != null ? '${user.weightKg!.toStringAsFixed(1)} kg' : 'Chưa rõ',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBmiCard(double bmi, String category, Color color, String advice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉ số khối cơ thể (BMI)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tỷ lệ cân nặng & chiều cao',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.cardBorder),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Họ và tên
        const Text('Họ và tên', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: _inputDecoration('Nhập họ và tên', prefixIcon: Icons.person_outline_rounded),
        ),
        const SizedBox(height: 18),

        // Giới tính & Năm sinh (Row)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giới tính', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: _inputDecoration('Giới tính'),
                    items: ['Nam', 'Nữ', 'Khác'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedGender = val ?? 'Nam';
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Năm sinh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedBirthYear,
                    decoration: _inputDecoration('Năm sinh'),
                    items: List.generate(75, (index) => 1950 + index).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBirthYear = val ?? 1995;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Chiều cao & Cân nặng (Row)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chiều cao (cm)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Ví dụ: 170', suffixText: 'cm'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cân nặng (kg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Ví dụ: 65.5', suffixText: 'kg'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Mục tiêu giấc ngủ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final timeParts = _targetBedtime.split(':');
                  final initialTime = timeParts.length == 2
                      ? TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]))
                      : const TimeOfDay(hour: 23, minute: 0);
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                    helpText: 'Chọn giờ đi ngủ mục tiêu',
                  );
                  if (picked != null) {
                    setState(() {
                      _targetBedtime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: _buildTimeDisplayCard('Giờ đi ngủ', _targetBedtime),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final timeParts = _targetWakeTime.split(':');
                  final initialTime = timeParts.length == 2
                      ? TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]))
                      : const TimeOfDay(hour: 7, minute: 0);
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                    helpText: 'Chọn giờ thức dậy mục tiêu',
                  );
                  if (picked != null) {
                    setState(() {
                      _targetWakeTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: _buildTimeDisplayCard('Giờ thức dậy', _targetWakeTime),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Tần suất tập luyện', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _activityLevel,
          decoration: _inputDecoration('Tần suất tập luyện', prefixIcon: Icons.fitness_center_rounded),
          items: [
            'Không tập luyện',
            'Ít (1-2 ngày/tuần)',
            'Vừa phải (3-5 ngày/tuần)',
            'Nhiều (6-7 ngày/tuần)',
          ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (val) {
            setState(() {
              _activityLevel = val ?? 'Vừa phải (3-5 ngày/tuần)';
            });
          },
        ),
      ],
    );
  }

  Widget _buildActivityLevelSection(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fitness_center_rounded, color: Colors.teal, size: 22),
              SizedBox(width: 10),
              Text(
                'Tần suất tập luyện',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.activityLevel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplayCard(String title, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTargetsSection(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.nights_stay_rounded, color: Colors.indigo, size: 22),
              SizedBox(width: 10),
              Text(
                'Mục tiêu giấc ngủ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ đi ngủ mục tiêu', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      user.targetBedtime,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Giờ dậy mục tiêu', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      user.targetWakeTime,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, {IconData? prefixIcon, String? suffixText}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textHint, size: 20) : null,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              setState(() {
                _isEditing = false;
                _initFields(); // Reset fields to actual values
              });
            },
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: isLoading ? null : _saveProfile,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'Lưu thay đổi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  final String? currentAvatarUrl;
  final Function(String) onAvatarSelected;

  const _AvatarPickerSheet({
    required this.currentAvatarUrl,
    required this.onAvatarSelected,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        onAvatarSelected('data:image/jpeg;base64,$base64String');
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải hoặc xử lý ảnh.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> emojis = [
      '👤', '👦', '👧', '👑', '⚔️', '🛡️', '🧪', '🦁', '🐉', '🦄', '🏃', '🧗', '🧘', '⚡', '🔥', '❤️'
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle & Title
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chọn ảnh đại diện',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ─── TỰ CHỌN ẢNH ───
            const Text(
              'Từ thiết bị của bạn',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(context, ImageSource.camera),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Chụp ảnh mới',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(context, ImageSource.gallery),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Thư viện ảnh',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── EMOJIS ───
            const Text(
              'Biểu tượng Emoji',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                final isSelected = currentAvatarUrl == emoji;
                return GestureDetector(
                  onTap: () => onAvatarSelected(emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
