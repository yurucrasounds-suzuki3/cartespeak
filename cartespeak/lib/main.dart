class KarteDraft {
  List<String> menu = [];     // カット/カラー/縮毛矯正...
  String color = "";          // 暗めアッシュ 等
  String length = "";         // ボブ/ショート/肩くらい 等
  List<String> concerns = []; // 広がり/白髪/ダメージ 等
  String caution = "";        // 頭皮しみやすい 等
  String next = "";           // 6週間でリタッチ 等
  String memo = "";           // 元文章（保険）

  Map<String, dynamic> toMap() => {
    "menu": menu,
    "color": color,
    "length": length,
    "concerns": concerns,
    "caution": caution,
    "next": next,
    "memo": memo,
    "createdAt": FieldValue.serverTimestamp(),
  };
}

KarteDraft parseKarteFromText(String text) {
  final t = text.replaceAll(RegExp(r"\s+"), ""); // 空白除去
  final d = KarteDraft();
  d.memo = text;

  // ===== メニュー =====
  void addMenu(String label, List<String> words) {
    if (words.any((w) => t.contains(w)) && !d.menu.contains(label)) {
      d.menu.add(label);
    }
  }
  addMenu("カット", ["カット", "切って", "整えて", "毛量調整", "すいて"]);
  addMenu("カラー", ["カラー", "染め", "染める"]);
  addMenu("リタッチ", ["リタッチ", "根元"]);
  addMenu("トリートメント", ["トリートメント", "ケア", "補修", "髪質改善"]);
  addMenu("縮毛矯正", ["縮毛矯正", "ストレート", "酸性ストレート"]);
  addMenu("パーマ", ["パーマ", "デジパ", "デジタルパーマ"]);
  addMenu("ヘッドスパ", ["ヘッドスパ", "スパ", "炭酸", "スキャルプ"]);

  // ===== 色（超簡単）=====
  if (t.contains("アッシュ")) d.color = "アッシュ";
  if (t.contains("ベージュ")) d.color = "ベージュ";
  if (t.contains("ブラウン") || t.contains("茶")) d.color = d.color.isEmpty ? "ブラウン" : d.color;
  if (t.contains("グレージュ")) d.color = "グレージュ";
  if (t.contains("オリーブ") || t.contains("マット")) d.color = "オリーブ/マット";

  // 明るさ
  if (t.contains("暗め") || t.contains("トーンダウン") || t.contains("落ち着")) {
    d.color = d.color.isEmpty ? "暗め" : "暗め ${d.color}";
  }
  if (t.contains("明るめ") || t.contains("トーンアップ") || t.contains("ハイトーン")) {
    d.color = d.color.isEmpty ? "明るめ" : "明るめ ${d.color}";
  }

  // 意図
  if (t.contains("赤み消し") || t.contains("赤味消し") || t.contains("赤みを消")) {
    d.color = d.color.isEmpty ? "赤み消し" : "${d.color}（赤み消し）";
  }

  // ===== 長さ/スタイル =====
  if (t.contains("ボブ")) d.length = "ボブ";
  else if (t.contains("ショート")) d.length = "ショート";
  else if (t.contains("ロング")) d.length = "ロング";
  else if (t.contains("ミディアム")) d.length = "ミディアム";
  if (t.contains("肩") || t.contains("鎖骨")) d.length = d.length.isEmpty ? "肩くらい" : "${d.length}（肩くらい）";

  // ===== 悩み =====
  void addConcern(String label, List<String> words) {
    if (words.any((w) => t.contains(w)) && !d.concerns.contains(label)) {
      d.concerns.add(label);
    }
  }
  addConcern("広がり/うねり", ["広がり", "うねり", "まとまらない", "膨らむ"]);
  addConcern("白髪", ["白髪", "グレイ", "白髪ぼかし"]);
  addConcern("ダメージ", ["ダメージ", "傷み", "枝毛", "切れ毛", "ハイダメージ"]);
  addConcern("乾燥", ["乾燥", "パサつき", "ぱさぱさ"]);

  // ===== 注意（頭皮）=====
  if (t.contains("しみ") || t.contains("敏感") || t.contains("かぶれ") || t.contains("かゆ")) {
    d.caution = "頭皮が敏感/しみやすい";
  }

  // ===== 次回提案 =====
  // ざっくり「◯週間」「◯ヶ月」を拾う
  final m = RegExp(r"(\d+)(週間|週|ヶ月|か月|月)").firstMatch(text);
  final period = m == null ? "" : "${m.group(1)}${m.group(2)}";
  if (text.contains("次回") || text.contains("次は") || period.isNotEmpty) {
    final parts = <String>[];
    if (period.isNotEmpty) parts.add(period);
    if (text.contains("リタッチ") || text.contains("根元")) parts.add("リタッチ");
    if (text.contains("トリートメント")) parts.add("トリートメント");
    if (parts.isNotEmpty) d.next = parts.join(" / ");
  }

  return d;
}

final SpeechToText _stt = SpeechToText();
Timer? _autoStop;
String transcript = "";
KarteDraft draft = KarteDraft();

Future<void> startStt60s() async {
  final ok = await _stt.initialize();
  if (!ok) throw Exception("音声認識が使えません");

  transcript = "";
  await _stt.listen(
    localeId: "ja_JP",
    onResult: (res) {
      transcript = res.recognizedWords;
      // リアルタイム表示したいなら setState()
    },
  );

  _autoStop?.cancel();
  _autoStop = Timer(const Duration(seconds: 60), () async {
    await stopSttAndFill();
  });
}

Future<void> stopSttAndFill() async {
  _autoStop?.cancel();
  await _stt.stop();

  draft = parseKarteFromText(transcript);
  // setStateしてフォームに反映
}

Future<void> saveToFirestore(String salonId, String customerId, KarteDraft d) async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";

  final ref = FirebaseFirestore.instance
      .collection("salons").doc(salonId)
      .collection("customers").doc(customerId)
      .collection("records").doc();

  await ref.set({
    ...d.toMap(),
    "stylistId": uid,
    "source": "voice",
    "transcript": d.memo, // 保険
  });

  await FirebaseFirestore.instance
      .collection("salons").doc(salonId)
      .collection("customers").doc(customerId)
      .set({
        "lastVisitAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}