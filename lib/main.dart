import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const IsimsizceApp());
}

// ============================================================
// RENKLER
// ============================================================

class AppColors {
  static const background = Color(0xFF101524);
  static const surface = Color(0xFF1C243A);
  static const surfaceLight = Color(0xFF242D46);
  static const border = Color(0xFF303A55);

  static const purple = Color(0xFFB99AFF);
  static const purpleStrong = Color(0xFF9A6BFF);
  static const pink = Color(0xFFFF4D8D);

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
      String title,
      ) async {
    final cleanTitle = title.trim();

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
  int selectedIndex = 0;

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
        return '🆕 Yeni';

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

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: showCreateTopic,
        backgroundColor:
        AppColors.purpleStrong,
        foregroundColor: Colors.white,
        icon: const Text(
          '✍️',
          style: TextStyle(
            fontSize: 18,
          ),
        ),
        label: const Text(
          'Başlık Aç',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      bottomNavigationBar:
      _bottomNavigation(),
    );
  }

  Widget _header() {
    return Container(
      margin:
      const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        0,
      ),
      padding:
      const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const Text(
            '🕵️',
            style: TextStyle(
              fontSize: 23,
            ),
          ),

          const SizedBox(width: 8),

          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.w900,
              ),
              children: [
                TextSpan(
                  text: 'İsimsiz',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: 'ce',
                  style: TextStyle(
                    color:
                    AppColors.purple,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: loadTopics,
            tooltip: 'Yenile',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        42,
        20,
        42,
      ),
      child: Column(
        children: [
          const Text(
            'İsimsizce',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 45,
              height: 1,
              letterSpacing: -2,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'İsmini değil, fikrini bırak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            width: 52,
            height: 3,
            decoration: BoxDecoration(
              color:
              AppColors.purpleStrong,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
          ),
        ],
      ),
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
    final title =
        topic['title']?.toString() ??
            'Başlıksız';

    final entryCount =
        topic['entry_count']
            ?.toString() ??
            '0';

    final likeCount =
        topic['like_count']
            ?.toString() ??
            '0';

    final date =
        topic['created_at']
            ?.toString() ??
            '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: () async {
          final id = int.tryParse(
            topic['id'].toString(),
          );

          if (id == null) return;

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TopicPage(
                    topicId: id,
                  ),
            ),
          );

          if (mounted) {
            loadTopics();
          }
        },
        child: Ink(
          padding:
          const EdgeInsets.all(19),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 13,
              ),

              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  _meta(
                    '💬',
                    '$entryCount entry',
                  ),
                  _meta(
                    '💗',
                    likeCount,
                  ),
                  if (date.isNotEmpty)
                    _meta(
                      '•',
                      date,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                      keyboardType:
                      TextInputType
                          .multiline,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Entry',
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

  Widget _topicHeader() {
    return Container(
      padding:
      const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'BAŞLIK',
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            topic?['title']
                ?.toString() ??
                'Başlık',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.2,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            topic?['created_at']
                ?.toString() ??
                '',
            style: const TextStyle(
              color:
              AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(dynamic entry) {
    final nickname =
        entry['nickname']
            ?.toString() ??
            'anonim';

    final content =
        entry['content']
            ?.toString() ??
            '';

    final likes =
        entry['like_count']
            ?.toString() ??
            '0';

    final replies =
        entry['reply_count']
            ?.toString() ??
            '0';

    final date =
        entry['created_at']
            ?.toString() ??
            '';

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                alignment:
                Alignment.center,
                decoration:
                BoxDecoration(
                  color: AppColors
                      .purpleStrong
                      .withValues(
                    alpha: 0.18,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child:
                const Text('👤'),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  nickname,
                  style:
                  const TextStyle(
                    color:
                    AppColors.purple,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
              ),

              const Icon(
                Icons.more_horiz,
                color:
                AppColors.textMuted,
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            content,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.55,
            ),
          ),

          const SizedBox(
            height: 17,
          ),

          Text(
            date,
            style: const TextStyle(
              color:
              AppColors.textMuted,
              fontSize: 11,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Row(
            children: [
              _entryAction(
                '💗',
                likes,
              ),

              const SizedBox(
                width: 10,
              ),

              _entryAction(
                '💬',
                replies,
              ),

              const Spacer(),

              const Icon(
                Icons.flag_outlined,
                size: 19,
                color:
                AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
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