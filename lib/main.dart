import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const IsimsizceApp());
}

String displayDate(String value, {bool includeTime = false}) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  final label = '${date.day} ${months[date.month - 1]} ${date.year}';
  return includeTime
    ? '$label, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
    : label;
}

int countEmojis(String value) {
  final emojiPattern = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}]|[0-9#*]\u{FE0F}?\u{20E3}',
    unicode: true,
  );
  return value.characters.where((part) => emojiPattern.hasMatch(part)).length;
}

class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({super.key, required this.controller,
    required this.maxLength, this.maxEmojis, this.enabled = true});
  final TextEditingController controller;
  final int maxLength;
  final int? maxEmojis;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: !enabled ? null : () async {
      final emoji = await showModalBottomSheet<String>(
        context: context, backgroundColor: AppColors.surface,
        builder: (pickerContext) => SafeArea(
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Emoji ekle', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: Wrap(
                spacing: 4, runSpacing: 4,
                children: ['😀','😃','😄','😁','😅','😂','🤣','😊','🙂','🙃',
                  '😉','😍','🥰','😘','😎','🤔','🤫','🤗','🥺','😢','😭',
                  '😡','🤯','😴','🙄','😶','🕵️','❤️','💜','💙','💗',
                  '🔥','✨','⭐','☀️','🌙','🌧️','🌈','🎉','🎈','💫',
                  '👍','👎','👏','🙌','🤝','👋','🙏','💪','👌','✍️',
                  '💬','🚀','🎵','☕','🌹','🍀','✅','❓'].map((value) =>
                  SizedBox(width: 46, height: 46, child: TextButton(
                    onPressed: () => Navigator.pop(pickerContext, value),
                    child: Text(value, style: const TextStyle(fontSize: 24)),
                  ))).toList(),
              ))),
            ]),
          ),
        ),
      );
      if (emoji == null || !context.mounted) return;
      final selection = controller.selection;
      final start = selection.isValid ? selection.start : controller.text.length;
      final end = selection.isValid ? selection.end : controller.text.length;
      final next = controller.text.replaceRange(start, end, emoji);
      if (next.characters.length > maxLength ||
          (maxEmojis != null && countEmojis(next) > maxEmojis!)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          maxEmojis != null && countEmojis(next) > maxEmojis!
            ? 'Başlıkta en fazla $maxEmojis emoji kullanabilirsin.'
            : 'En fazla $maxLength karakter kullanabilirsin.')));
        return;
      }
      controller.value = TextEditingValue(text: next,
        selection: TextSelection.collapsed(offset: start + emoji.length));
    },
    icon: const Text('😊'), label: const Text('Emoji ekle'),
  );
}

// ============================================================
// RENKLER
// ============================================================

class AppColors {
  static const background = Color(0xFF141625);
  static const surface = Color(0xFF22263A);
  static const surfaceLight = Color(0xFF292D43);
  static const border = Color(0xFF36384F);

  static const purple = Color(0xFFB99AFF);
  static const purpleStrong = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);

  static const text = Color(0xFFF5F5FA);
  static const textSoft = Color(0xFFB9BDD0);
  static const textMuted = Color(0xFF8F96AD);
}

// ============================================================
// UYGULAMA
// ============================================================

class IsimsizceApp extends StatelessWidget {
  const IsimsizceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İsimsizce',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.purple,
          secondary: AppColors.pink,
          surface: AppColors.surface,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// ANONİM KİMLİK
// ============================================================

class AnonymousIdentity {
  static const String _tokenKey = 'isimsizce_anonymous_token';

  static bool _validToken(String? token) {
    if (token == null) return false;

    return RegExp(
      r'^[a-f0-9]{64}$',
    ).hasMatch(token);
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_tokenKey);

    if (_validToken(saved)) {
      return saved!;
    }

    final random = Random.secure();

    final token = List.generate(
      32,
          (_) => random
          .nextInt(256)
          .toRadixString(16)
          .padLeft(2, '0'),
    ).join();

    await prefs.setString(
      _tokenKey,
      token,
    );

    return token;
  }

  static Future<void> saveTopicToken(
      dynamic topicId,
      String? token,
      ) async {
    if (topicId == null || !_validToken(token)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'topic_token_$topicId',
      token!,
    );
  }

  static Future<void> saveEntryToken(
      dynamic entryId,
      String? token,
      ) async {
    if (entryId == null || !_validToken(token)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'entry_token_$entryId',
      token!,
    );
  }
}

// ============================================================
// API
// ============================================================

class ApiService {
  static Future<Map<String, dynamic>> sendAction(
    String endpoint, Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: await _headers(),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 20));
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw Exception('Sunucudan geçersiz cevap geldi.');
    }
    if (decoded is! Map || response.statusCode < 200 ||
        response.statusCode >= 300 || decoded['ok'] != true) {
      throw Exception(decoded is Map
          ? decoded['error']?.toString() ?? 'İşlem tamamlanamadı.'
          : 'İşlem tamamlanamadı.');
    }
    return Map<String, dynamic>.from(decoded);
  }
  static const String baseUrl =
      'https://isimsizce.nurullahyrmz.com/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AnonymousIdentity.getToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Anonymous-Token': token,
    };
  }

  // ----------------------------------------------------------
  // BAŞLIKLARI GETİR
  // ----------------------------------------------------------

  static Future<List<dynamic>> getTopics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/topics.php'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Başlıklar alınamadı. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Sunucudan geçersiz cevap geldi.',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Başlıklar alınamadı.',
      );
    }

    if (decoded['ok'] != true) {
      throw Exception(
        decoded['error']?.toString() ??
            'Başlıklar alınamadı.',
      );
    }

    return decoded['topics'] ?? [];
  }

  // ----------------------------------------------------------
  // TEK BAŞLIK + ENTRYLER
  // ----------------------------------------------------------

  static Future<Map<String, dynamic>> getTopic(
      int id,
      ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/topic.php?id=$id',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Başlık açılamadı. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Sunucudan geçersiz cevap geldi.',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Başlık açılamadı.',
      );
    }

    if (decoded['ok'] != true) {
      throw Exception(
        decoded['error']?.toString() ??
            'Başlık açılamadı.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ----------------------------------------------------------
  // BAŞLIK OLUŞTUR
  // ----------------------------------------------------------

  static Future<Map<String, dynamic>> createTopic(
      String title, {
        bool useNickname = false,
        String nickname = "",
      }) async {
    final cleanTitle = title.trim();
    final cleanNickname = nickname.trim();
    if (useNickname && (cleanNickname.isEmpty || cleanNickname.length > 30)) {
      throw Exception('Takma ad 1–30 karakter olmalı.');
    }

    if (countEmojis(cleanTitle) > 3) {
      throw Exception('Başlıkta en fazla 3 emoji kullanabilirsin.');
    }

    if (cleanTitle.isEmpty) {
      throw Exception(
        'Başlık boş bırakılamaz.',
      );
    }

    if (cleanTitle.length > 150) {
      throw Exception(
        'Başlık en fazla 150 karakter olabilir.',
      );
    }

    final token =
    await AnonymousIdentity.getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/topics.php'),
      headers: await _headers(),
      body: jsonEncode({
        'title': cleanTitle,
        'use_nickname': useNickname,
        'nickname': useNickname ? cleanNickname : 'Anonim',
        'anonymous_token': token,
      }),
    );

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Sunucudan geçersiz cevap geldi. '
            'HTTP ${response.statusCode}',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Başlık oluşturulamadı.',
      );
    }

    final data =
    Map<String, dynamic>.from(decoded);

    if ((response.statusCode != 200 &&
        response.statusCode != 201) ||
        data['ok'] != true) {
      throw Exception(
        data['error']?.toString() ??
            'Başlık oluşturulamadı. '
                'HTTP ${response.statusCode}',
      );
    }

    final topicId =
        data['topic_id'] ?? data['id'];

    final returnedToken =
        data['anonymous_token']?.toString() ??
            data['token']?.toString();

    if (returnedToken != null) {
      await AnonymousIdentity.saveTopicToken(
        topicId,
        returnedToken,
      );
    } else {
      await AnonymousIdentity.saveTopicToken(
        topicId,
        token,
      );
    }

    return data;
  }

  // ----------------------------------------------------------
  // ENTRY OLUŞTUR
  // ----------------------------------------------------------

  static Future<Map<String, dynamic>> createEntry({
    required int topicId,
    required String nickname,
    required String content,
  }) async {
    final cleanNickname = nickname.trim();
    final cleanContent = content.trim();

    if (cleanContent.runes.length > 1000) {
      throw Exception('Entry en fazla 1.000 karakter olabilir.');
    }

    if (cleanNickname.isEmpty) {
      throw Exception(
        'Rumuz boş bırakılamaz.',
      );
    }

    if (cleanNickname.length > 30) {
      throw Exception(
        'Rumuz en fazla 30 karakter olabilir.',
      );
    }

    if (cleanContent.isEmpty) {
      throw Exception(
        'Entry boş bırakılamaz.',
      );
    }

    final token =
    await AnonymousIdentity.getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/entries.php'),
      headers: await _headers(),
      body: jsonEncode({
        'topic_id': topicId,
        'nickname': cleanNickname,
        'content': cleanContent,
        'anonymous_token': token,
      }),
    );

    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Sunucudan geçersiz cevap geldi. '
            'HTTP ${response.statusCode}',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Entry gönderilemedi.',
      );
    }

    final data =
    Map<String, dynamic>.from(decoded);

    if ((response.statusCode != 200 &&
        response.statusCode != 201) ||
        data['ok'] != true) {
      throw Exception(
        data['error']?.toString() ??
            'Entry gönderilemedi. '
                'HTTP ${response.statusCode}',
      );
    }

    final entryId =
        data['entry_id'] ?? data['id'];

    final returnedToken =
        data['anonymous_token']?.toString() ??
            data['token']?.toString();

    if (returnedToken != null) {
      await AnonymousIdentity.saveEntryToken(
        entryId,
        returnedToken,
      );
    } else {
      await AnonymousIdentity.saveEntryToken(
        entryId,
        token,
      );
    }

    return data;
  }
}

// ============================================================
// ANA SAYFA
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 1;

  bool loading = true;
  String? error;

  List<dynamic> topics = [];

  final TextEditingController searchController =
  TextEditingController();

  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadTopics();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTopics() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result =
      await ApiService.getTopics();

      if (!mounted) return;

      setState(() {
        topics = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = _cleanError(e);
        loading = false;
      });
    }
  }

  String _cleanError(Object e) {
    return e
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }

  List<dynamic> get visibleTopics {
    final list =
    List<dynamic>.from(topics);

    if (selectedIndex == 1) {
      list.sort((a, b) {
        final aId =
            int.tryParse(
              a['id'].toString(),
            ) ??
                0;

        final bId =
            int.tryParse(
              b['id'].toString(),
            ) ??
                0;

        return bId.compareTo(aId);
      });
    }

    if (selectedIndex == 2) {
      list.sort((a, b) {
        final aLikes =
            int.tryParse(
              a['like_count'].toString(),
            ) ??
                0;

        final bLikes =
            int.tryParse(
              b['like_count'].toString(),
            ) ??
                0;

        return bLikes.compareTo(aLikes);
      });
    }

    if (selectedIndex == 3 &&
        searchText.trim().isNotEmpty) {
      final query =
      searchText.toLowerCase().trim();

      return list.where((topic) {
        final title =
            topic['title']
                ?.toString()
                .toLowerCase() ??
                '';

        return title.contains(query);
      }).toList();
    }

    return list;
  }

  String get sectionTitle {
    switch (selectedIndex) {
      case 1:
        return '📝 Yeni Başlıklar';

      case 2:
        return '💗 Popüler';

      case 3:
        return '🔍 Ara';

      default:
        return '🔥 Gündem';
    }
  }

  // ==========================================================
  // BAŞLIK AÇ
  // ==========================================================

  Future<void> showCreateTopic() async {
    final titleController =
    TextEditingController();

    final topicNicknameController = TextEditingController();
    bool useNickname = false;
    bool submitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
              context,
              setSheetState,
              ) {
            Future<void> submit() async {
              final title =
              titleController.text.trim();

              if (title.isEmpty) {
                setSheetState(() {
                  formError =
                  'Başlık boş bırakılamaz.';
                });

                return;
              }

              if (title.length > 150) {
                setSheetState(() {
                  formError =
                  'Başlık en fazla 150 karakter olabilir.';
                });

                return;
              }

              setSheetState(() {
                submitting = true;
                formError = null;
              });

              try {
                await ApiService.createTopic(
                  title,
                  useNickname: useNickname,
                  nickname: topicNicknameController.text,
                );

                if (!mounted) return;

                if (sheetContext.mounted) {
                  Navigator.pop(
                    sheetContext,
                  );
                }

                setState(() {
                  selectedIndex = 0;
                });

                await loadTopics();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Başlık yayınlandı. ✅',
                    ),
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  submitting = false;
                  formError = _cleanError(e);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                    24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '✍️',
                          style: TextStyle(
                            fontSize: 25,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Başlık Aç',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextField(
                      controller:
                      titleController,
                      autofocus: true,
                      maxLength: 150,
                      enabled: !submitting,
                      textInputAction:
                      TextInputAction.done,
                      onSubmitted: (_) {
                        if (!submitting) {
                          submit();
                        }
                      },
                      decoration:
                      InputDecoration(
                        labelText:
                        'Başlık',
                        suffixIcon: EmojiPickerButton(controller: titleController,
                          maxLength: 150, maxEmojis: 3, enabled: !submitting),
                        hintText:
                        'Ne hakkında konuşmak istiyorsun?',
                        filled: true,
                        fillColor:
                        AppColors
                            .surfaceLight,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(14),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(14),
                          borderSide:
                          const BorderSide(
                            color:
                            AppColors
                                .purple,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Takma adla paylaş'),
                      subtitle: Text(useNickname
                          ? 'Başlık takma adınla paylaşılacak.'
                          : 'Başlık anonim paylaşılacak.'),
                      value: useNickname,
                      onChanged: submitting ? null : (value) {
                        setSheetState(() { useNickname = value; formError = null; });
                      },
                    ),
                    if (useNickname) TextField(
                      controller: topicNicknameController,
                      enabled: !submitting,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Takma ad',
                        hintText: 'Nasıl görünmek istersin?',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (formError != null) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        formError!,
                        style:
                        const TextStyle(
                          color:
                          Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 16,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      child: FilledButton(
                        onPressed:
                        submitting
                            ? null
                            : submit,
                        style:
                        FilledButton
                            .styleFrom(
                          backgroundColor:
                          AppColors
                              .purpleStrong,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 15,
                          ),
                        ),
                        child: submitting
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.5,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Text(
                          'Yayınla',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

  }

  // ==========================================================
  // ANA EKRAN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadTopics,
          child: CustomScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _header(),
              ),

              SliverToBoxAdapter(
                child: _hero(),
              ),

              SliverToBoxAdapter(
                child: _sectionHeader(),
              ),

              if (selectedIndex == 3)
                SliverToBoxAdapter(
                  child: _searchBox(),
                ),

              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child:
                    CircularProgressIndicator(
                      color:
                      AppColors.purple,
                    ),
                  ),
                )
              else if (error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorView(),
                )
              else if (visibleTopics.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Henüz başlık yok.',
                        style: TextStyle(
                          color:
                          AppColors.textSoft,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      120,
                    ),
                    sliver:
                    SliverList.separated(
                      itemCount:
                      visibleTopics.length,
                      separatorBuilder:
                          (_, __) =>
                      const SizedBox(
                        height: 12,
                      ),
                      itemBuilder:
                          (context, index) {
                        return _topicCard(
                          visibleTopics[
                          index],
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _header() {
    final menu = <({String label, VoidCallback action, bool active})>[
      (label: '🏠 Ana Sayfa', action: () => setState(() => selectedIndex = 1), active: selectedIndex == 1),
      (label: '🔥 Gündem', action: () => setState(() => selectedIndex = 0), active: selectedIndex == 0),
      (label: '❤️ Popüler', action: () => setState(() => selectedIndex = 2), active: selectedIndex == 2),
      (label: '🔍 Ara', action: () => setState(() => selectedIndex = 3), active: selectedIndex == 3),
      (label: '✍️ Başlık Aç', action: showCreateTopic, active: false),
      (label: '📖 Kurallar', action: _showRules, active: false),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🕵️', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('İsimsizce', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Anonim Sözlük', style: TextStyle(fontSize: 12,
                color: AppColors.textSoft))])),
          IconButton(onPressed: loadTopics, tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) => Wrap(
          spacing: 6, runSpacing: 6,
          children: menu.map((item) => SizedBox(
            width: (constraints.maxWidth - 12) / 3,
            child: OutlinedButton(onPressed: item.action,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: item.active
                  ? AppColors.purpleStrong.withValues(alpha: .22)
                  : Colors.white.withValues(alpha: .035),
                side: BorderSide(color: item.active ? AppColors.purpleStrong : AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(item.label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          )).toList(),
        )),
      ]),
    );
  }

  void _showRules() {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Kurallar ve Yardım'),
      content: const SingleChildScrollView(child: Text(
        'İsmini değil, fikrini bırak.\n\n'
        'Gerçek adını kullanmak zorunda değilsin. Kişisel bilgileri paylaşma. '
        'Hakaret, tehdit ve spam gönderme. Uygunsuz entryleri Şikâyet Et ile bildirebilirsin.\n\n'
        'Başlık: en fazla 150 karakter ve 3 emoji.\n'
        'Takma ad: en fazla 30 karakter.\nEntry: en fazla 1.000 karakter.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Kapat'))],
    ));
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(children: [
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('İsimsizce Hakkında'),
              content: const Text('İsmini değil, fikrini bırak.\n\n'
                'Başlık aç, fikirlerini paylaş ve diğer entryleri keşfet. '
                'Gerçek adını kullanmak zorunda değilsin. '
                'Kişisel bilgileri paylaşma; hakaret, tehdit ve spam gönderme.'),
              actions: [TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Kapat'))],
            ),
          ),
          icon: const Text('🕵️'), label: const Text('İsimsizce Hakkında'),
        ),
        const SizedBox(height: 18),
        const Text('İsmini değil, fikrini bırak.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.purpleStrong, AppColors.pink]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextButton(
            onPressed: showCreateTopic,
            style: TextButton.styleFrom(foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16)),
            child: const Text('✍️ Başlık Aç',
              style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }



  Widget _sectionHeader() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        16,
      ),
      child: Row(
        children: [
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 23,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const Spacer(),

          Text(
            '${visibleTopics.length} başlık',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16,
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchText = value;
          });
        },
        decoration: InputDecoration(
          hintText:
          'Başlıklarda ara...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.purple,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16),
            borderSide:
            const BorderSide(
              color: AppColors.border,
            ),
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16),
            borderSide:
            const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16),
            borderSide:
            const BorderSide(
              color: AppColors.purple,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topicCard(dynamic topic) {
    final title = topic['title']?.toString() ?? 'Başlıksız';
    final count = topic['entry_count']?.toString() ?? '0';
    final likes = topic['like_count']?.toString() ?? '0';
    final date = displayDate(topic['created_at']?.toString() ?? '');
    final number = visibleTopics.indexOf(topic) + 1;
    return Stack(clipBehavior: Clip.none, children: [
      Material(color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border)),
        child: InkWell(borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final id = int.tryParse(topic['id'].toString());
            if (id == null) return;
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => TopicPage(topicId: id)));
            if (mounted) await loadTopics();
          },
          child: Padding(padding: const EdgeInsets.all(19),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, height: 1.3,
                fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              if (count == '0') ...[
                const Text('Henüz entry yok. İlk entry’yi sen yaz.',
                  style: TextStyle(color: AppColors.textSoft, height: 1.6)),
                const SizedBox(height: 12),
              ],
              Wrap(spacing: 16, runSpacing: 8, children: [
                _meta('💬', '$count entry'), _meta('❤️', likes),
                if (date.isNotEmpty) _meta('📅', 'Açılış: $date'),
              ]),
            ])),
        )),
      Positioned(left: -6, top: 18, child: Container(
        width: 27, height: 27, alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.purpleStrong, AppColors.pink])),
        child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)),
      )),
    ]);
  }

  Widget _meta(
      String icon,
      String text,
      ) {
    return Text(
      '$icon  $text',
      style: const TextStyle(
        color: AppColors.textSoft,
        fontSize: 12,
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.purple,
              size: 46,
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Başlıklar yüklenemedi',
              style: TextStyle(
                fontWeight:
                FontWeight.w800,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error ?? '',
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                color:
                AppColors.textSoft,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            FilledButton(
              onPressed: loadTopics,
              child: const Text(
                'Tekrar Dene',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavigation() {
    return NavigationBar(
      height: 72,
      backgroundColor:
      AppColors.surface,
      indicatorColor:
      AppColors.purpleStrong
          .withValues(
        alpha: 0.24,
      ),
      selectedIndex: selectedIndex,
      onDestinationSelected:
          (index) {
        setState(() {
          selectedIndex = index;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Text(
            '🔥',
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          label: 'Gündem',
        ),

        NavigationDestination(
          icon: Text(
            '🆕',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          label: 'Yeni',
        ),

        NavigationDestination(
          icon: Text(
            '💗',
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          label: 'Popüler',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.search_rounded,
          ),
          label: 'Ara',
        ),
      ],
    );
  }
}

// ============================================================
// BAŞLIK DETAY SAYFASI
// ============================================================

class TopicPage extends StatefulWidget {
  final int topicId;

  const TopicPage({
    super.key,
    required this.topicId,
  });

  @override
  State<TopicPage> createState() =>
      _TopicPageState();
}

class _TopicPageState
    extends State<TopicPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? topic;
  List<dynamic> entries = [];

  @override
  void initState() {
    super.initState();
    loadTopic();
  }

  String _cleanError(Object e) {
    return e
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }

  Future<void> loadTopic() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result =
      await ApiService.getTopic(
        widget.topicId,
      );

      if (!mounted) return;

      setState(() {
        topic =
        Map<String, dynamic>.from(
          result['topic'] ?? {},
        );

        entries =
            result['entries'] ?? [];

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = _cleanError(e);
        loading = false;
      });
    }
  }

  // ==========================================================
  // ENTRY YAZ
  // ==========================================================

  Future<void> showCreateEntry() async {
    final nicknameController =
    TextEditingController();

    final contentController =
    TextEditingController();

    bool submitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
              context,
              setSheetState,
              ) {
            Future<void> submit() async {
              final nickname =
              nicknameController.text
                  .trim();

              final content =
              contentController.text
                  .trim();

              if (nickname.isEmpty) {
                setSheetState(() {
                  formError =
                  'Rumuzunu yaz.';
                });

                return;
              }

              if (nickname.length > 30) {
                setSheetState(() {
                  formError =
                  'Rumuz en fazla 30 karakter olabilir.';
                });

                return;
              }

              if (content.isEmpty) {
                setSheetState(() {
                  formError =
                  'Entry boş bırakılamaz.';
                });

                return;
              }

              setSheetState(() {
                submitting = true;
                formError = null;
              });

              try {
                await ApiService.createEntry(
                  topicId:
                  widget.topicId,
                  nickname: nickname,
                  content: content,
                );

                if (!mounted) return;

                if (sheetContext.mounted) {
                  Navigator.pop(
                    sheetContext,
                  );
                }

                await loadTopic();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Entry yayınlandı. ✅',
                    ),
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  submitting = false;
                  formError =
                      _cleanError(e);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                    24,
              ),
              child:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '💬',
                          style: TextStyle(
                            fontSize: 24,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Entry Yaz',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextField(
                      controller:
                      nicknameController,
                      maxLength: 30,
                      enabled:
                      !submitting,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Rumuz',
                        hintText:
                        'örn. isimsizbiri',
                        filled: true,
                        fillColor:
                        AppColors
                            .surfaceLight,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            AppColors
                                .purple,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    TextField(
                      controller:
                      contentController,
                      autofocus: true,
                      enabled:
                      !submitting,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      keyboardType:
                      TextInputType
                          .multiline,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Entry',
                        suffixIcon: EmojiPickerButton(controller: contentController,
                          maxLength: 1000, enabled: !submitting),
                        hintText:
                        'Fikrini yaz...',
                        alignLabelWithHint:
                        true,
                        filled: true,
                        fillColor:
                        AppColors
                            .surfaceLight,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            AppColors
                                .purple,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    if (formError != null) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      Text(
                        formError!,
                        style:
                        const TextStyle(
                          color:
                          Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 18,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      child: FilledButton(
                        onPressed:
                        submitting
                            ? null
                            : submit,
                        style:
                        FilledButton
                            .styleFrom(
                          backgroundColor:
                          AppColors
                              .purpleStrong,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 15,
                          ),
                        ),
                        child: submitting
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.5,
                            color:
                            Colors.white,
                          ),
                        )
                            : const Text(
                          'Entry Yayınla',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

  }

  // ==========================================================
  // SAYFA
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar: AppBar(
        backgroundColor:
        AppColors.background,
        surfaceTintColor:
        Colors.transparent,
        title: const Text(
          '🕵️ İsimsizce',
          style: TextStyle(
            fontWeight:
            FontWeight.w900,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: loadTopic,
        child: loading
            ? const Center(
          child:
          CircularProgressIndicator(
            color:
            AppColors.purple,
          ),
        )
            : error != null
            ? ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(
              height: 180,
            ),
            Center(
              child: Padding(
                padding:
                const EdgeInsets
                    .all(25),
                child: Column(
                  children: [
                    Text(
                      error!,
                      textAlign:
                      TextAlign
                          .center,
                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSoft,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    FilledButton(
                      onPressed:
                      loadTopic,
                      child:
                      const Text(
                        'Tekrar Dene',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
            : ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets
              .fromLTRB(
            16,
            12,
            16,
            40,
          ),
          children: [
            _topicHeader(),

            const SizedBox(
              height: 25,
            ),

            Row(
              children: [
                const Text(
                  '💬 Entryler',
                  style:
                  TextStyle(
                    fontSize:
                    21,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),

                const Spacer(),

                Text(
                  '${entries.length} entry',
                  style:
                  const TextStyle(
                    color:
                    AppColors
                        .purple,
                    fontSize:
                    12,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 13,
            ),

            if (entries.isEmpty)
              _emptyEntries()
            else
              ...entries.map(
                    (entry) =>
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        bottom: 12,
                      ),
                      child:
                      _entryCard(
                        entry,
                      ),
                    ),
              ),

            const SizedBox(
              height: 15,
            ),

            _writeEntryButton(),
          ],
        ),
      ),
    );
  }

  Widget _topicHeader() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(topic?['title']?.toString() ?? 'Başlık',
        style: const TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 8, children: [
        Text('💬 ${entries.length} entry', style: const TextStyle(color: AppColors.textSoft)),
        Text('📅 ${displayDate(topic?['created_at']?.toString() ?? '', includeTime: true)}',
          style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
      ]),
    ]),
  );

  final Set<String> _entryBusy = {};

  void _actionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _likeEntry(dynamic entry) async {
    final id = int.tryParse(entry['id'].toString());
    if (id == null || _entryBusy.contains('$id')) return;
    setState(() => _entryBusy.add('$id'));
    try {
      final result = await ApiService.sendAction('likes.php', {'entry_id': id});
      if (result['liked'] == true) {
        await loadTopic();
      } else {
        _actionMessage('Bu entry için beğeni eklenemedi veya daha önce beğendin.');
      }
    } catch (error) {
      _actionMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _entryBusy.remove('$id'));
    }
  }

  Future<void> _reportEntry(dynamic entry) async {
    final id = int.tryParse(entry['id'].toString());
    if (id == null || _entryBusy.contains('$id')) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entry şikâyeti'),
        content: TextField(
          controller: controller, maxLength: 500, maxLines: 4,
          decoration: const InputDecoration(labelText: 'Şikâyet nedeni'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          }, child: const Text('Gönder')),
        ],
      ),
    );
    if (!mounted || reason == null) return;
    setState(() => _entryBusy.add('$id'));
    try {
      await ApiService.sendAction('reports.php', {'entry_id': id, 'reason': reason});
      _actionMessage('Şikâyetin iletildi.');
    } catch (error) {
      _actionMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _entryBusy.remove('$id'));
    }
  }

  Widget _entryCard(dynamic entry) {
    final id = entry['id'].toString();
    final busy = _entryBusy.contains(id);
    final number = entries.indexOf(entry) + 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 6, children: [
          Text('#$number', style: const TextStyle(color: AppColors.purple,
            fontWeight: FontWeight.w800)),
          Text('👤 ${entry['nickname'] ?? 'Anonim'}',
            style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700)),
          Text('📅 ${displayDate(entry['created_at']?.toString() ?? '', includeTime: true)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        SelectableText(entry['content']?.toString() ?? '',
          style: const TextStyle(fontSize: 16, height: 1.65, color: AppColors.text)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton(onPressed: busy ? null : () => _likeEntry(entry),
            child: Text('❤️ ${entry['like_count'] ?? 0}')),
          OutlinedButton(onPressed: busy ? null : () => _reportEntry(entry),
            child: const Text('🚨 Şikâyet Et')),
        ]),
        if (entry['replies'] is List && (entry['replies'] as List).isNotEmpty) ...[
          const Divider(height: 28),
          ...(entry['replies'] as List).map((reply) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('↳ ${reply['nickname'] ?? 'Anonim'}',
                style: const TextStyle(color: AppColors.purple)),
              const SizedBox(height: 5),
              Text(reply['content']?.toString() ?? '',
                style: const TextStyle(height: 1.5)),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _entryAction(
      String icon,
      String value,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Text(
        '$icon  $value',
        style: const TextStyle(
          color: AppColors.textSoft,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _emptyEntries() {
    return Container(
      padding:
      const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Center(
        child: Text(
          'Bu başlıkta henüz entry yok.',
          style: TextStyle(
            color: AppColors.textSoft,
          ),
        ),
      ),
    );
  }

  Widget _writeEntryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showCreateEntry,
        borderRadius:
        BorderRadius.circular(18),
        child: Ink(
          padding:
          const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: AppColors
                  .purpleStrong
                  .withValues(
                alpha: 0.45,
              ),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: AppColors.purple,
              ),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Bu başlığa entry yaz...',
                  style: TextStyle(
                    color:
                    AppColors.textSoft,
                  ),
                ),
              ),

              Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 15,
                color:
                AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


