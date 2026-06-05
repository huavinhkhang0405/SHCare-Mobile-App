import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/pet_model.dart';
import '../../../services/pet/pet_service.dart';
import '../../../providers/auth_provider.dart';
import '../../home/widgets/ai_pet_widget.dart';

class PetDashboardScreen extends StatefulWidget {
  final String userId; // Nhận từ Auth, ví dụ tạm thời: "test_user_01"

  const PetDashboardScreen({super.key, required this.userId});

  @override
  State<PetDashboardScreen> createState() => _PetDashboardScreenState();
}

class _PetDashboardScreenState extends State<PetDashboardScreen> {
  final PetService _petService = PetService();
  int _previousLevel = 1; // Dùng để kích hoạt cờ isLevelUp cho AIPetWidget

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50), // Màu nền tuỳ chỉnh cho hợp với Aura
      appBar: AppBar(title: const Text("SHCare Pet")),
      body: StreamBuilder<PetModel>(
        stream: _petService.streamPetData(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pet = snapshot.data ?? PetModel(id: 'temp', userId: widget.userId);

          // Kiểm tra xem có lên cấp không để trigger animation
          bool isLevelUp = false;
          if (pet.level > _previousLevel) {
            isLevelUp = true;
            _previousLevel = pet.level; // Cập nhật lại level hiện tại
          } else if (pet.level < _previousLevel) {
             // Reset trong trường hợp load data mới
            _previousLevel = pet.level;
          }

          // Map state từ Tiếng Việt (trong model) sang Tiếng Anh để AIPetWidget hiểu
          String animState = 'idle';
          if (pet.state == 'Mệt mỏi' || pet.state == 'Khát') animState = 'tired';
          if (pet.state == 'Năng động' || pet.state == 'Vui vẻ') animState = 'happy';

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Core Widget: Pet Animation của bạn
              AIPetWidget(
                petState: animState,
                classType: pet.classType,
                level: pet.level,
                isLevelUp: isLevelUp,
                userName: auth.userName.isNotEmpty ? auth.userName : 'Khang',
              ),

              const SizedBox(height: 20),

              // 2. Thanh kinh nghiệm (Exp Bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cấp ${pet.level}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("${pet.currentExp} / ${pet.expToNextLevel} EXP", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: pet.expProgress, // Gọi getter expProgress từ Model của bạn
                        minHeight: 12,
                        backgroundColor: Colors.black45,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 3. Nút giả lập hoàn thành nhiệm vụ để test luồng
              ElevatedButton.icon(
                onPressed: () {
                  // Giả sử hoàn thành 1 task sức khoẻ được 30 điểm
                  _petService.gainExperience(widget.userId, 30);
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("Test: Hoàn thành Task (+30 EXP)"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}