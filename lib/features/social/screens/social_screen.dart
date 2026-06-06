import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/pet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../home/providers/health_provider.dart';
import '../../../services/social/social_service.dart';
import '../../../services/firebase/user_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'qr_scanner_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final TextEditingController _friendCodeController = TextEditingController();
  final TextEditingController _searchFriendController = TextEditingController();
  final SocialService _socialService = SocialService();
  bool _isAddingFriend = false;
  bool _isMatchingFacebookFriends = false;
  bool _isLoadingLeaderboard = false;
  bool _showIdInput = false;
  List<PetModel> _leaderboard = [];
  String _searchFriendQuery = '';
  
  String? _lastUserId;
  List<String>? _lastFriends;

  static const Map<int, String> _sprites = {
    1: 'assets/images/sprites/sprite_r01_c01.png',
    2: 'assets/images/sprites/sprite_r02_c01.png',
    3: 'assets/images/sprites/sprite_r03_c01.png',
    4: 'assets/images/sprites/sprite_r04_c01.png',
    5: 'assets/images/sprites/sprite_r05_c01.png',
    6: 'assets/images/sprites/sprite_r06_c01.png',
    7: 'assets/images/sprites/sprite_r07_c01.png',
    8: 'assets/images/sprites/sprite_r08_c01.png',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final health = Provider.of<HealthProvider>(context);
    final currentUserId = auth.currentUser?.id;
    final currentFriends = health.currentUser?.friends ?? [];

    if (currentUserId != null && 
        (currentUserId != _lastUserId || !_areListsEqual(currentFriends, _lastFriends))) {
      _lastUserId = currentUserId;
      _lastFriends = List.from(currentFriends);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  bool _areListsEqual(List<String> a, List<String>? b) {
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _friendCodeController.dispose();
    _searchFriendController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLeaderboard = true;
    });

    final auth = context.read<AuthProvider>();
    final health = context.read<HealthProvider>();
    final myUid = auth.currentUser?.id ?? '';

    // Tự sinh và lưu mã kết bạn nếu chưa có hoặc không hợp lệ (Tránh treo xoay vòng ở acc mới tạo)
    if (auth.currentUser != null && 
        (auth.currentUser!.friendCode.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(auth.currentUser!.friendCode))) {
      try {
        final code = await _socialService.generateUniqueFriendCode(auth.currentUser!.name);
        final updatedUser = auth.currentUser!.copyWith(friendCode: code);
        await UserService().saveUser(updatedUser);
        await auth.reloadUserData();
      } catch (e) {
        debugPrint('🚨 [SocialScreen] Lỗi tự động sinh mã kết bạn: $e');
      }
    }

    // Lấy thông tin user mới nhất để có mảng friends cập nhật
    try {
      if (myUid.isNotEmpty) {
        final leaderboardList = await _socialService.fetchLeaderboard(
          myUid,
          health.currentUser?.friends ?? [],
        );
        if (mounted) {
          setState(() {
            _leaderboard = leaderboardList;
          });
        }
      }
    } catch (e) {
      debugPrint('🚨 [SocialScreen] Lỗi fetchLeaderboard: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _handleAddFriend() async {
    final code = _friendCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isAddingFriend = true;
    });

    final auth = context.read<AuthProvider>();
    final myUid = auth.currentUser?.id ?? '';
    final messenger = ScaffoldMessenger.of(context);

    final result = await _socialService.sendFriendRequest(code, myUid);

    if (mounted) {
      setState(() {
        _isAddingFriend = false;
      });

      String message = '';
      Color bgColor = Colors.red;

      switch (result) {
        case FriendRequestResult.sent:
          message = 'Đã gửi lời mời kết bạn thành công! Chờ đối phương xác nhận.';
          bgColor = Colors.green;
          _friendCodeController.clear();
          break;
        case FriendRequestResult.alreadyFriends:
          message = 'Hai bạn đã là bạn bè của nhau rồi!';
          bgColor = Colors.blue;
          _friendCodeController.clear();
          break;
        case FriendRequestResult.alreadyRequested:
          message = 'Bạn đã gửi lời mời kết bạn trước đó rồi, vui lòng chờ duyệt!';
          bgColor = Colors.orange;
          _friendCodeController.clear();
          break;
        case FriendRequestResult.autoAccepted:
          message = 'Đối phương cũng đã gửi lời mời trước đó! Hai bạn đã trở thành bạn bè.';
          bgColor = Colors.green;
          _friendCodeController.clear();
          // Tải lại thông tin user trong AuthProvider để cập nhật mảng friends
          await auth.reloadUserData();
          // Load lại leaderboard
          await _loadData();
          break;
        case FriendRequestResult.selfConnect:
          message = 'Không thể kết bạn với chính mình!';
          bgColor = Colors.orange;
          break;
        case FriendRequestResult.notFound:
          message = 'Không tìm thấy mã kết bạn tương ứng!';
          bgColor = Colors.red;
          break;
        case FriendRequestResult.error:
        default:
          message = 'Đã xảy ra lỗi khi kết bạn. Vui lòng thử lại!';
          bgColor = Colors.red;
          break;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleAcceptRequest(String myUid, String requesterId, String requesterName) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    final success = await _socialService.acceptFriendRequest(myUid, requesterId);

    if (mounted) {
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã chấp nhận lời mời kết bạn từ $requesterName! 👥'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Reload user info to update list of friends
        await auth.reloadUserData();
        // Load leaderboard again
        await _loadData();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Chấp nhận kết bạn thất bại. Vui lòng thử lại!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(String myUid, String requesterId, String requesterName) async {
    final messenger = ScaffoldMessenger.of(context);

    final success = await _socialService.declineFriendRequest(myUid, requesterId);

    if (mounted) {
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã từ chối lời mời kết bạn từ $requesterName!'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Từ chối kết bạn thất bại. Vui lòng thử lại!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleFacebookFriendMatch() async {
    setState(() {
      _isMatchingFacebookFriends = true;
    });

    final auth = context.read<AuthProvider>();
    final myUid = auth.currentUser?.id ?? '';
    final messenger = ScaffoldMessenger.of(context);

    try {
      final addedFriends = await _socialService.linkFacebookFriends(myUid);
      if (mounted) {
        setState(() {
          _isMatchingFacebookFriends = false;
        });

        if (addedFriends.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Đã tự động kết bạn qua Facebook với: ${addedFriends.join(", ")}! 👥'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Tải lại thông tin user trong AuthProvider
          await auth.reloadUserData();
          // Load lại leaderboard
          await _loadData();
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy bạn bè mới nào từ Facebook sử dụng ứng dụng.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMatchingFacebookFriends = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối Facebook: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPokeBottomSheet(PetModel friendPet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF111826), // Nền tối
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Chọc ghẹo ${friendPet.ownerName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nhắc nhở bạn bè rèn sức khỏe bằng phong cách Gen Z hài hước!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPokeOptionTile(
                  icon: '👣',
                  title: 'Chọc lười vận động',
                  subtitle: 'Gửi lời chọc vì làm [Cột sống bất ổn]',
                  onTap: () => _sendPokeAndPop(friendPet.userId, 'lazy'),
                ),
                const SizedBox(height: 12),
                _buildPokeOptionTile(
                  icon: '💧',
                  title: 'Chọc lười uống nước',
                  subtitle: 'Nhắc nhở cây héo uống nước ngay [Sa mạc lời]',
                  onTap: () => _sendPokeAndPop(friendPet.userId, 'water'),
                ),
                const SizedBox(height: 12),
                _buildPokeOptionTile(
                  icon: '🌙',
                  title: 'Chọc thức khuya',
                  subtitle: 'Giục cú đêm deadline đi ngủ gấp',
                  onTap: () => _sendPokeAndPop(friendPet.userId, 'sleep'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendPokeAndPop(String friendId, String pokeType) async {
    Navigator.pop(context);
    final auth = context.read<AuthProvider>();
    final myUid = auth.currentUser?.id ?? '';
    final myName = auth.userName.isNotEmpty ? auth.userName : 'Bạn bè';
    final messenger = ScaffoldMessenger.of(context);

    final success = await _socialService.sendPoke(
      friendId,
      myUid,
      myName,
      pokeType,
    );

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã chọc ghẹo thành công!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gửi chọc ghẹo thất bại. Vui lòng thử lại!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPokeOptionTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF162033),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHayDayMenuItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconBgColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String title) {
    List<Color> gradientColors;
    Color shadowColor;
    String emoji;

    switch (title) {
      case 'Cột sống bất ổn':
        gradientColors = [const Color(0xFFFF416C), const Color(0xFFFF4B2B)];
        shadowColor = const Color(0xFFFF4B2B).withOpacity(0.4);
        emoji = '👣';
        break;
      case 'Sa mạc lời':
        gradientColors = [const Color(0xFFF12711), const Color(0xFFF5AF19)];
        shadowColor = const Color(0xFFF5AF19).withOpacity(0.4);
        emoji = '💧';
        break;
      case 'Cú đêm deadline':
      case 'Cú đêm suy tình':
        gradientColors = [const Color(0xFF8A2387), const Color(0xFFE94057)];
        shadowColor = const Color(0xFFE94057).withOpacity(0.4);
        emoji = '🌙';
        break;
      case 'Kẻ hủy diệt nước lọc':
        gradientColors = [const Color(0xFF00B4DB), const Color(0xFF0083B0)];
        shadowColor = const Color(0xFF0083B0).withOpacity(0.4);
        emoji = '🥤';
        break;
      case 'Bậc thầy xê dịch':
        gradientColors = [const Color(0xFF11998E), const Color(0xFF38EF7D)];
        shadowColor = const Color(0xFF38EF7D).withOpacity(0.4);
        emoji = '👟';
        break;
      case 'Sleeping Beauty':
      case 'Chiến thần ngủ ngon':
        gradientColors = [const Color(0xFFFF758C), const Color(0xFFFF7EB3)];
        shadowColor = const Color(0xFFFF7EB3).withOpacity(0.4);
        emoji = '😴';
        break;
      case 'Chiến thần KPI':
      default:
        gradientColors = [const Color(0xFFF1C40F), const Color(0xFFF39C12)];
        shadowColor = const Color(0xFFF39C12).withOpacity(0.4);
        emoji = '👑';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.currentUser?.id ?? '';
    final myFriendCode = auth.currentUser?.friendCode ?? '';

    final filteredBoard = _leaderboard.where((pet) {
      if (_searchFriendQuery.isEmpty) return true;
      return pet.ownerName.toLowerCase().contains(_searchFriendQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cộng đồng',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Đọ Pet sức khỏe cùng bè bạn',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // CARD CHỨA HỒ SƠ & MÃ QR (HAYDAY STYLE)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0).withOpacity(0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Hàng trên: Thông tin user bên trái, QR Code bên phải
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Thông tin User (Trái)
                              Expanded(
                                child: Row(
                                  children: [
                                    // Avatar của tôi
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFFFD54F), // Viền vàng như HayDay
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFD54F).withOpacity(0.2),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          _sprites[4]!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Tên và mã code
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: constraints.maxWidth,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    auth.userName.isNotEmpty ? auth.userName : 'Người dùng SHCare',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              // Badge Mã kết bạn
                                              GestureDetector(
                                                onTap: () {
                                                  if (myFriendCode.isNotEmpty) {
                                                    Clipboard.setData(
                                                      ClipboardData(text: myFriendCode),
                                                    );
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Đã sao chép mã kết bạn! 📋'),
                                                        behavior: SnackBarBehavior.floating,
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E293B),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: AppColors.primary.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.tag_rounded,
                                                        size: 11,
                                                        color: AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        myFriendCode.isNotEmpty ? myFriendCode : 'Đang tạo...',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.primary,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(
                                                        Icons.copy_rounded,
                                                        size: 11,
                                                        color: Colors.white54,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // QR Code (Phải)
                              if (myFriendCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFFD54F), // Viền vàng như HayDay
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: myFriendCode,
                                    version: QrVersions.auto,
                                    size: 72.0,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                              else
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // MENU HÀNH ĐỘNG KẾT BẠN (HAYDAY STYLE)
                          // 1. Nhập Player ID
                          _buildHayDayMenuItem(
                            icon: Icons.tag_rounded,
                            iconBgColor: const Color(0xFF3B82F6),
                            title: 'Kết bạn bằng Player ID',
                            onTap: () {
                              setState(() {
                                _showIdInput = !_showIdInput;
                              });
                            },
                            trailing: Icon(
                              _showIdInput ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ),
                          // Dropdown nhập mã kết bạn
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _showIdInput
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 42,
                                            child: TextField(
                                              controller: _friendCodeController,
                                              textCapitalization: TextCapitalization.characters,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              decoration: InputDecoration(
                                                hintText: 'Nhập mã kết bạn (VD: KHAN99X)...',
                                                hintStyle: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textHint,
                                                ),
                                                fillColor: const Color(0xFF1E293B),
                                                filled: true,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(
                                                    color: AppColors.primary.withOpacity(0.3),
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 42,
                                          child: FilledButton(
                                            onPressed: _isAddingFriend ? null : _handleAddFriend,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                            ),
                                            child: _isAddingFriend
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Kết bạn',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 10),

                          // 2. Quét mã QR
                          _buildHayDayMenuItem(
                            icon: Icons.qr_code_scanner_rounded,
                            iconBgColor: const Color(0xFF10B981),
                            title: 'Quét mã QR',
                            onTap: () async {
                              final scannedCode = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const QRScannerScreen(),
                                ),
                              );
                              if (scannedCode != null && scannedCode.isNotEmpty) {
                                _friendCodeController.text = scannedCode;
                                setState(() {
                                  _showIdInput = true;
                                });
                                _handleAddFriend();
                              }
                            },
                          ),
                          const SizedBox(height: 10),

                          // 3. Tìm bạn qua Facebook
                          _buildHayDayMenuItem(
                            icon: Icons.facebook_rounded,
                            iconBgColor: const Color(0xFF1877F2),
                            title: 'Tìm bạn qua Facebook',
                            onTap: _isMatchingFacebookFriends ? () {} : _handleFacebookFriendMatch,
                            trailing: _isMatchingFacebookFriends
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white54,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    _buildFriendRequestsSection(myUid),
                    const SizedBox(height: 24),

                    if (_isLoadingLeaderboard)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_leaderboard.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_add_rounded,
                              size: 64,
                              color: AppColors.textHint.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Kết bạn ngay thôi!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Nhập mã của bạn bè để đọ Pet và chọc ghẹo thi đua nhé.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Search bar to filter friends
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _searchFriendController,
                          onChanged: (val) {
                            setState(() {
                              _searchFriendQuery = val.trim();
                            });
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm bạn bè theo tên...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Colors.white38,
                              size: 18,
                            ),
                            suffixIcon: _searchFriendQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white38),
                                    onPressed: () {
                                      setState(() {
                                        _searchFriendQuery = '';
                                        _searchFriendController.clear();
                                      });
                                    },
                                  )
                                : null,
                            fillColor: const Color(0xFF162033),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),

                      if (_searchFriendQuery.isEmpty) ...[
                        // BỤC VINH QUANG PODIUM (TOP 3)
                        _buildPodium(_leaderboard),
                        const SizedBox(height: 24),
                      ],

                      // BẢNG XẾP HẠNG THƯỜNG (#4 trở đi)
                      Text(
                        _searchFriendQuery.isEmpty ? 'Bảng xếp hạng' : 'Kết quả tìm kiếm',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filteredBoard.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: const Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                              SizedBox(height: 12),
                              Text(
                                'Không tìm thấy bạn bè nào phù hợp',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredBoard.length,
                          itemBuilder: (context, index) {
                            final idx = index;
                            final pet = filteredBoard[idx];
                            final isMe = pet.userId == myUid;
                            final sprite = _sprites[pet.classType] ?? _sprites[4]!;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primarySurface.withOpacity(0.3)
                                    : AppColors.cardBg,
                                borderRadius:
                                    BorderRadius.circular(AppColors.radiusMd),
                                border: Border.all(
                                  color: isMe
                                      ? AppColors.primary.withOpacity(0.3)
                                      : AppColors.cardBorder,
                                  width: isMe ? 1.5 : 1.0,
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Row(
                                children: [
                                  // Rank number
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '#${_leaderboard.indexOf(pet) + 1}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  // Avatar Pet
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.scaffoldBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.cardBorder,
                                      ),
                                    ),
                                    child: Image.asset(sprite),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name, Title and Level
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                pet.ownerName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? AppColors.primaryDark
                                                      : AppColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.star_rounded,
                                                color: AppColors.primary,
                                                size: 14,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Lv. ${pet.level}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: _buildBadge(pet.currentTitle),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action
                                  if (!isMe)
                                    IconButton(
                                      onPressed: () => _showPokeBottomSheet(pet),
                                      icon: const Icon(
                                        Icons.front_hand_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.primarySurface,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<PetModel> board) {
    final length = board.length;
    PetModel? first = length > 0 ? board[0] : null;
    PetModel? second = length > 1 ? board[1] : null;
    PetModel? third = length > 2 ? board[2] : null;

    final myUid = context.read<AuthProvider>().currentUser?.id ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text(
                'Bục vinh quang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // HẠNG 2 (Bên trái)
              if (second != null)
                Expanded(child: _buildPodiumItem(second, 2, 85, myUid))
              else
                Expanded(child: const SizedBox()),

              const SizedBox(width: 8),

              // HẠNG 1 (Ở giữa)
              if (first != null)
                Expanded(child: _buildPodiumItem(first, 1, 110, myUid))
              else
                Expanded(child: const SizedBox()),

              const SizedBox(width: 8),

              // HẠNG 3 (Bên phải)
              if (third != null)
                Expanded(child: _buildPodiumItem(third, 3, 65, myUid))
              else
                Expanded(child: const SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(PetModel pet, int rank, double podiumHeight, String myUid) {
    final sprite = _sprites[pet.classType] ?? _sprites[4]!;
    final isMe = pet.userId == myUid;

    Color crownColor;
    String crownIcon;
    List<Color> podiumGradients;

    if (rank == 1) {
      crownColor = Colors.amber;
      crownIcon = '👑';
      podiumGradients = [const Color(0xFFFFD54F), const Color(0xFFFFB300)];
    } else if (rank == 2) {
      crownColor = Colors.grey;
      crownIcon = '🥈';
      podiumGradients = [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)];
    } else {
      crownColor = Colors.brown;
      crownIcon = '🥉';
      podiumGradients = [const Color(0xFFFFCC80), const Color(0xFFCA8A04)];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vương miện
            Text(crownIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            // Avatar tròn của Pet
            GestureDetector(
              onTap: isMe ? null : () => _showPokeBottomSheet(pet),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: crownColor,
                        width: rank == 1 ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: crownColor.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: AppColors.scaffoldBg,
                        child: Image.asset(sprite),
                      ),
                    ),
                  ),
                  if (!isMe)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.front_hand_rounded,
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tên
            SizedBox(
              width: maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  pet.ownerName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Level + Badge
            Text(
              'Lv.${pet.level}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: _buildBadge(pet.currentTitle),
              ),
            ),
            const SizedBox(height: 10),
            // Bục đứng
            Container(
              height: podiumHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: podiumGradients,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendRequestsSection(String myUid) {
    if (myUid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _socialService.streamFriendRequests(myUid),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lời mời kết bạn (${requests.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final doc = requests[index];
                final data = doc.data() as Map<String, dynamic>;
                final requesterId = doc.id;
                final name = data['sender_name'] as String? ?? 'Người dùng SHCare';
                final avatar = data['sender_avatar'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162033),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      UserAvatar(
                        avatarUrl: avatar,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      // Tên
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nút Từ chối
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => _handleDeclineRequest(myUid, requesterId, name),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Đồng ý
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: () => _handleAcceptRequest(myUid, requesterId, name),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Đồng ý',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
