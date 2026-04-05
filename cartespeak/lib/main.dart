import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '美容室カルテ MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const KartePage(),
    );
  }
}

class KarteDraft {
  String customerName = '';
  String menu = '';
  String color = '';
  String length = '';
  String concerns = '';
  String caution = '';
  String next = '';
  String memo = '';
}

KarteDraft parseKarteFromText(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), '');
  final d = KarteDraft();
  d.memo = text;

  final menus = <String>[];
  final concerns = <String>[];

  void addMenu(String label, List<String> words) {
    if (words.any((w) => t.contains(w)) && !menus.contains(label)) {
      menus.add(label);
    }
  }

  void addConcern(String label, List<String> words) {
    if (words.any((w) => t.contains(w)) && !concerns.contains(label)) {
      concerns.add(label);
    }
  }

  addMenu('カット', ['カット', '切って', '整えて', '毛量調整', 'すいて']);
  addMenu('カラー', ['カラー', '染め', '染める']);
  addMenu('リタッチ', ['リタッチ', '根元']);
  addMenu('トリートメント', ['トリートメント', 'ケア', '補修', '髪質改善']);
  addMenu('縮毛矯正', ['縮毛矯正', 'ストレート', '酸性ストレート']);
  addMenu('パーマ', ['パーマ', 'デジパ', 'デジタルパーマ']);
  addMenu('ヘッドスパ', ['ヘッドスパ', 'スパ', '炭酸', 'スキャルプ']);

  d.menu = menus.join(' / ');

  if (t.contains('グレージュ')) {
    d.color = 'グレージュ';
  } else if (t.contains('アッシュ')) {
    d.color = 'アッシュ';
  } else if (t.contains('ベージュ')) {
    d.color = 'ベージュ';
  } else if (t.contains('ブラウン') || t.contains('茶')) {
    d.color = 'ブラウン';
  } else if (t.contains('オリーブ') || t.contains('マット')) {
    d.color = 'オリーブ/マット';
  }

  if (t.contains('暗め') || t.contains('トーンダウン') || t.contains('落ち着')) {
    d.color = d.color.isEmpty ? '暗め' : '暗め $d.color';
  }

  if (t.contains('明るめ') || t.contains('トーンアップ') || t.contains('ハイトーン')) {
    d.color = d.color.isEmpty ? '明るめ' : '明るめ $d.color';
  }

  if (t.contains('赤み消し') || t.contains('赤味消し') || t.contains('赤みを消')) {
    d.color = d.color.isEmpty ? '赤み消し' : '$d.color（赤み消し）';
  }

  if (t.contains('ボブ')) {
    d.length = 'ボブ';
  } else if (t.contains('ショート')) {
    d.length = 'ショート';
  } else if (t.contains('ロング')) {
    d.length = 'ロング';
  } else if (t.contains('ミディアム')) {
    d.length = 'ミディアム';
  }

  if (t.contains('肩') || t.contains('鎖骨')) {
    d.length = d.length.isEmpty ? '肩くらい' : '${d.length}（肩くらい）';
  }

  addConcern('広がり/うねり', ['広がり', 'うねり', 'まとまらない', '膨らむ']);
  addConcern('白髪', ['白髪', 'グレイ', '白髪ぼかし']);
  addConcern('ダメージ', ['ダメージ', '傷み', '枝毛', '切れ毛', 'ハイダメージ']);
  addConcern('乾燥', ['乾燥', 'パサつき', 'ぱさぱさ']);

  d.concerns = concerns.join(' / ');

  if (t.contains('しみ') || t.contains('敏感') || t.contains('かぶれ') || t.contains('かゆ')) {
    d.caution = '頭皮が敏感/しみやすい';
  }

  final match = RegExp(r'(\d+)(週間|週|ヶ月|か月|月)').firstMatch(text);
  final period = match == null ? '' : '${match.group(1)}${match.group(2)}';

  if (text.contains('次回') || text.contains('次は') || period.isNotEmpty) {
    final parts = <String>[];
    if (period.isNotEmpty) parts.add(period);
    if (text.contains('リタッチ') || text.contains('根元')) parts.add('リタッチ');
    if (text.contains('トリートメント')) parts.add('トリートメント');
    d.next = parts.join(' / ');
  }

  return d;
}

Future<void> sendToSheet({
  required String apiUrl,
  required String customerName,
  required String menu,
  required String color,
  required String length,
  required String concerns,
  required String caution,
  required String next,
  required String memo,
  required String transcript,
}) async {
  final res = await http.post(
    Uri.parse(apiUrl),
    body: {
      'customerName': customerName,
      'menu': menu,
      'color': color,
      'length': length,
      'concerns': concerns,
      'caution': caution,
      'next': next,
      'memo': memo,
      'transcript': transcript,
    },
  );

  if (res.statusCode != 200) {
    throw Exception('送信失敗: ${res.statusCode} ${res.body}');
  }
}

class KartePage extends StatefulWidget {
  const KartePage({super.key});

  @override
  State<KartePage> createState() => _KartePageState();
}

class _KartePageState extends State<KartePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  // ここを自分のGASの /exec URL に置き換える
  final String _apiUrl = 'https://script.google.com/macros/s/AKfycbw0y91e5IPgZ8XutQlubbEnJhY4C28flat3eMPYPMMcdjVgmOuaOh0ox7XJyPpIbv4f/exec';

  final _customerNameController = TextEditingController();
  final _menuController = TextEditingController();
  final _colorController = TextEditingController();
  final _lengthController = TextEditingController();
  final _concernsController = TextEditingController();
  final _cautionController = TextEditingController();
  final _nextController = TextEditingController();
  final _memoController = TextEditingController();

  bool _isListening = false;
  bool _isSending = false;
  String _statusText = '待機中';
  String _recognizedText = '';
  int _remainingSeconds = 60;

  Timer? _autoStopTimer;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _customerNameController.dispose();
    _menuController.dispose();
    _colorController.dispose();
    _lengthController.dispose();
    _concernsController.dispose();
    _cautionController.dispose();
    _nextController.dispose();
    _memoController.dispose();
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('status: $status');
      },
      onError: (error) {
        setState(() {
          _statusText = '音声認識エラー: ${error.errorMsg}';
          _isListening = false;
        });
      },
    );

    if (!available) {
      setState(() {
        _statusText = '音声認識が使えません';
      });
      return;
    }

    setState(() {
      _recognizedText = '';
      _isListening = true;
      _statusText = '音声入力中...';
      _remainingSeconds = 60;
    });

    await _speech.listen(
      localeId: 'ja_JP',
      partialResults: true,
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      },
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
      }
      setState(() {
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, 60);
      });
    });

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 60), () async {
      await stopListeningAndFill();
    });
  }

  Future<void> stopListeningAndFill() async {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();

    await _speech.stop();

    final draft = parseKarteFromText(_recognizedText);

    setState(() {
      _isListening = false;
      _statusText = '文字起こし完了';

      _menuController.text = draft.menu;
      _colorController.text = draft.color;
      _lengthController.text = draft.length;
      _concernsController.text = draft.concerns;
      _cautionController.text = draft.caution;
      _nextController.text = draft.next;
      _memoController.text = draft.memo;
    });
  }

  Future<void> submit() async {
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('顧客名を入れてください')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _statusText = '送信中...';
    });

    try {
      await sendToSheet(
        apiUrl: _apiUrl,
        customerName: _customerNameController.text.trim(),
        menu: _menuController.text.trim(),
        color: _colorController.text.trim(),
        length: _lengthController.text.trim(),
        concerns: _concernsController.text.trim(),
        caution: _cautionController.text.trim(),
        next: _nextController.text.trim(),
        memo: _memoController.text.trim(),
        transcript: _recognizedText,
      );

      setState(() {
        _statusText = '送信完了';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スプレッドシートに保存しました')),
      );
    } catch (e) {
      setState(() {
        _statusText = '送信失敗';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void clearAll() {
    setState(() {
      _recognizedText = '';
      _statusText = 'クリアしました';
      _customerNameController.clear();
      _menuController.clear();
      _colorController.clear();
      _lengthController.clear();
      _concernsController.clear();
      _cautionController.clear();
      _nextController.clear();
      _memoController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _isListening ? '停止して反映' : '録音開始（60秒）';

    return Scaffold(
      appBar: AppBar(
        title: const Text('美容室カルテ MVP'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '顧客情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerNameController,
            decoration: const InputDecoration(
              labelText: '顧客名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '音声入力',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '例：今日はカットとカラー。暗めアッシュで赤み消し。頭皮しみやすい。次回6週間でリタッチ。',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSending
                          ? null
                          : () async {
                              if (_isListening) {
                                await stopListeningAndFill();
                              } else {
                                await startListening();
                              }
                            },
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(buttonText),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('状態: $_statusText'),
                  if (_isListening) Text('残り: $_remainingSeconds 秒'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '文字起こし結果',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _recognizedText.isEmpty ? 'まだ文字起こしされていません' : _recognizedText,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'カルテ項目',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _menuController,
            decoration: const InputDecoration(
              labelText: '施術',
              hintText: 'カット / カラー',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _colorController,
            decoration: const InputDecoration(
              labelText: '色',
              hintText: '暗めアッシュ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lengthController,
            decoration: const InputDecoration(
              labelText: '長さ',
              hintText: 'ボブ / ショート / 肩くらい',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _concernsController,
            decoration: const InputDecoration(
              labelText: '悩み',
              hintText: '白髪 / 広がり / ダメージ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cautionController,
            decoration: const InputDecoration(
              labelText: '注意点',
              hintText: '頭皮が敏感 / しみやすい',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nextController,
            decoration: const InputDecoration(
              labelText: '次回提案',
              hintText: '6週間 / リタッチ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'メモ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSending ? null : clearAll,
                  child: const Text('クリア'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSending ? null : submit,
                  child: Text(_isSending ? '送信中...' : '送信'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}