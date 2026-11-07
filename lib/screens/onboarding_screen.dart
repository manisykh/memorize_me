import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 5;
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      backgroundColor: _Palette.canvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.15, -0.12),
            radius: 1.18,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4FAFF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              return Column(
                children: [
                  _Header(
                    showSkip: !last,
                    onSkip: widget.onFinished,
                    compact: compact,
                  ),
                  _TopProgress(current: _page),
                  SizedBox(height: compact ? 8 : 16),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (value) => setState(() => _page = value),
                      children: const [
                        _OnboardingPage(
                          firstTitle: '내 단어장으로',
                          secondTitle: '바로 시작',
                          subtitle: '가지고 있는 단어를 곧바로 학습에 연결하세요.',
                          artwork: _WordbookArtwork(),
                        ),
                        _OnboardingPage(
                          inlineTitle: true,
                          firstTitle: '익히고 ',
                          secondTitle: '바로 확인해요',
                          subtitle: '카드로 기억하고 문제로 점검하세요.',
                          artwork: _PracticeArtwork(),
                        ),
                        _OnboardingPage(
                          firstTitle: '복습할 날은',
                          secondTitle: '앱이 정리해요',
                          subtitle: '기억 상태에 맞춰 다시 볼 때를 알려드려요.',
                          artwork: _SrsArtwork(),
                          footnote: '학습 결과에 따라 일정이 자동으로 달라져요.',
                        ),
                        _OnboardingPage(
                          firstTitle: '내 API로',
                          secondTitle: 'AI 학습을 더해요',
                          subtitle: '무료 API 또는 보유한 키를 안전하게 연결하세요.',
                          artwork: _AiArtwork(),
                          footnote: '예문·퀴즈·문법 문제 생성에 사용할 수 있어요.',
                        ),
                        _OnboardingPage(
                          firstTitle: '이제 학습을',
                          secondTitle: '시작하세요',
                          subtitle: '첫 단어장을 준비하면 오늘의 학습이 만들어져요.',
                          artwork: _FinishArtwork(),
                        ),
                      ],
                    ),
                  ),
                  _Footer(
                    current: _page,
                    onNext: _next,
                    onBrowse: widget.onFinished,
                    compact: compact,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showSkip,
    required this.onSkip,
    required this.compact,
  });

  final bool showSkip;
  final VoidCallback onSkip;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(22, compact ? 8 : 14, 20, 6),
    child: SizedBox(
      height: compact ? 44 : 50,
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18072A5C),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/icon_1.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 13),
          const Text(
            'Memorize Me',
            style: TextStyle(
              color: _Palette.green,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (showSkip)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: _Palette.muted,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('건너뛰기'),
                  SizedBox(width: 3),
                  Icon(CupertinoIcons.chevron_right, size: 17),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _TopProgress extends StatelessWidget {
  const _TopProgress({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${current + 1} / 5',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final active = index <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 23,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? _Palette.blue : _Palette.paleBlue,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    ),
  );
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.firstTitle,
    required this.secondTitle,
    required this.subtitle,
    required this.artwork,
    this.inlineTitle = false,
    this.footnote,
  });

  final String firstTitle;
  final String secondTitle;
  final String subtitle;
  final Widget artwork;
  final bool inlineTitle;
  final String? footnote;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 640;
      final titleSize = compact ? 29.0 : 34.0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            SizedBox(height: compact ? 8 : 22),
            if (inlineTitle)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: firstTitle),
                      TextSpan(
                        text: secondTitle,
                        style: const TextStyle(color: _Palette.green),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _Palette.navy,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                  ),
                ),
              )
            else
              Column(
                children: [
                  Text(
                    firstTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _Palette.navy,
                      fontSize: titleSize,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                  Text(
                    secondTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _Palette.green,
                      fontSize: titleSize,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                ],
              ),
            SizedBox(height: compact ? 8 : 13),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Palette.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 22),
            Expanded(child: artwork),
            if (footnote != null) ...[
              SizedBox(height: compact ? 5 : 10),
              Text(
                footnote!,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Palette.muted,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _HaloPanel extends StatelessWidget {
  const _HaloPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white, width: 9),
      boxShadow: const [
        BoxShadow(
          color: Color(0x150A61B8),
          blurRadius: 30,
          spreadRadius: 2,
          offset: Offset(0, 10),
        ),
      ],
    ),
    padding: const EdgeInsets.all(10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5FA)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    ),
  );
}

class _ScaledArtwork extends StatelessWidget {
  const _ScaledArtwork({required this.child, this.height = 430});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 340,
        height: height,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child,
        ),
      ),
    ),
  );
}

class _WordbookArtwork extends StatelessWidget {
  const _WordbookArtwork();

  @override
  Widget build(BuildContext context) => _HaloPanel(
    child: _ScaledArtwork(
      child: Column(
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: _Palette.softGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBE6DF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/google_sheet_icon.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 14),
                const Flexible(
                  child: Text(
                    'Google Sheets',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Palette.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Icon(
            CupertinoIcons.arrow_down,
            size: 32,
            color: Color(0xFFAAB9CF),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFBFDFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _Palette.border),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                children: [
                  const Row(
                    children: [
                      _RoundIcon(
                        icon: CupertinoIcons.book_fill,
                        color: _Palette.green,
                        background: Color(0xFFEAF6F2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '나의 단어장',
                        style: TextStyle(
                          color: _Palette.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _Palette.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Column(
                      children: [
                        _WordRow(word: 'resilient', meaning: '회복력 있는'),
                        _WordRow(word: 'practical', meaning: '실용적인'),
                        _WordRow(
                          word: 'approach',
                          meaning: '접근하다',
                          divider: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              Expanded(
                flex: 5,
                child: _ImportChip(
                  label: 'Google Sheets',
                  icon: CupertinoIcons.table_fill,
                  color: Color(0xFF17A866),
                  background: Color(0xFFF0F8F6),
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                flex: 3,
                child: _ImportChip(
                  label: 'CSV',
                  icon: CupertinoIcons.doc_fill,
                  color: Color(0xFF718097),
                  background: Color(0xFFF3F6F9),
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                flex: 3,
                child: _ImportChip(
                  label: 'XLSX',
                  icon: CupertinoIcons.table_fill,
                  color: Color(0xFF087B45),
                  background: Color(0xFFF1F6F4),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PracticeArtwork extends StatelessWidget {
  const _PracticeArtwork();

  @override
  Widget build(BuildContext context) => _HaloPanel(
    child: _ScaledArtwork(
      height: 460,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _Palette.border),
              ),
              padding: EdgeInsets.zero,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 310,
                  // Keep enough design-space for the flashcard content. The
                  // surrounding FittedBox scales the whole card on compact
                  // devices instead of letting the inner Column overflow.
                  height: 330,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: _PracticeFlashcardContent(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _RoundIcon(
                icon: CupertinoIcons.chart_bar_fill,
                color: _Palette.green,
                background: Color(0xFFEAF8F3),
              ),
              SizedBox(width: 10),
              Text(
                '원하는 방식으로 확인',
                style: TextStyle(
                  color: _Palette.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: CupertinoIcons.doc_text_fill,
                  title: '객관식',
                  color: _Palette.blue,
                  background: Color(0xFFF1F7FF),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ModeCard(
                  icon: CupertinoIcons.pencil,
                  title: '스펠링',
                  subtitle: '주관식',
                  color: Color(0xFFFF625E),
                  background: Color(0xFFFFF2F2),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ModeCard(
                  icon: CupertinoIcons.doc_fill,
                  title: '시험지',
                  subtitle: 'PDF 생성',
                  color: Color(0xFF7849EF),
                  background: Color(0xFFF6F1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            '앱에서 풀거나 시험지로 만들어 확인할 수 있어요.',
            style: TextStyle(
              color: _Palette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PracticeFlashcardContent extends StatelessWidget {
  const _PracticeFlashcardContent();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          _Tag(
            icon: CupertinoIcons.book_fill,
            text: '단어',
            color: _Palette.green,
            background: Color(0xFFEAF8F3),
          ),
          Spacer(),
          _Tag(
            icon: CupertinoIcons.book_fill,
            text: '학습 중',
            color: Color(0xFFE98A00),
            background: Color(0xFFFFF5E7),
          ),
        ],
      ),
      const Spacer(),
      const Text(
        'resilient',
        style: TextStyle(
          color: _Palette.navy,
          fontSize: 39,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
      ),
      Container(
        width: 55,
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: _Palette.border,
      ),
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'She remained '),
            TextSpan(
              text: 'resilient',
              style: TextStyle(
                color: _Palette.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: '\nin difficult times.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _Palette.navy,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _Palette.blue, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.arrow_2_circlepath, color: _Palette.blue),
            SizedBox(width: 12),
            Text(
              '카드 뒤집기',
              style: TextStyle(
                color: _Palette.blue,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SrsArtwork extends StatelessWidget {
  const _SrsArtwork();

  @override
  Widget build(BuildContext context) => _HaloPanel(
    child: _ScaledArtwork(
      height: 420,
      child: Column(
        children: [
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF1FAF8),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '오늘 · 10월 15일',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Palette.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '복습 필요 ',
                  style: TextStyle(
                    color: _Palette.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '3개',
                  style: TextStyle(
                    color: Color(0xFFFF625E),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _StageTrack(),
          const SizedBox(height: 21),
          const Divider(height: 1, color: _Palette.border),
          const Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _ReviewRow(
                    title: '오늘 복습',
                    count: '3',
                    color: Color(0xFFFF5A56),
                    background: Color(0xFFFFEEEE),
                  ),
                ),
                Divider(height: 1, color: _Palette.border),
                Expanded(
                  child: _ReviewRow(
                    title: '내일 복습',
                    count: '0',
                    color: Color(0xFF1678E8),
                    background: Color(0xFFEAF4FF),
                  ),
                ),
                Divider(height: 1, color: _Palette.border),
                Expanded(
                  child: _ReviewRow(
                    title: '이번 주 복습',
                    count: '9',
                    color: Color(0xFF159B6D),
                    background: Color(0xFFEAF8F3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AiArtwork extends StatelessWidget {
  const _AiArtwork();

  @override
  Widget build(BuildContext context) => _HaloPanel(
    child: _ScaledArtwork(
      height: 425,
      child: Column(
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF2FBF9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFCBE6DF)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIcon(
                  icon: CupertinoIcons.lock_fill,
                  color: _Palette.green,
                  background: Color(0xFFE4F5F0),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'API 키는 이 기기에만 저장',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Palette.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _Palette.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Column(
              children: [
                _ProviderRow(
                  logo: 'G',
                  name: 'Google Gemini',
                  badge: '무료 시작',
                  logoColor: Color(0xFF3578EA),
                  logoBackground: Color(0xFFF1F6FF),
                  badgeColor: Color(0xFF159B6D),
                  badgeBackground: Color(0xFFEAF8F3),
                ),
                Divider(height: 1, color: _Palette.border),
                _ProviderRow(
                  logo: 'G',
                  name: 'Groq',
                  badge: '무료 시작',
                  logoColor: Color(0xFFF04432),
                  logoBackground: Color(0xFFFFF0EF),
                  badgeColor: Color(0xFF159B6D),
                  badgeBackground: Color(0xFFEAF8F3),
                ),
                Divider(height: 1, color: _Palette.border),
                _ProviderRow(
                  logo: 'O',
                  name: 'OpenRouter',
                  badge: '무료 모델',
                  logoColor: Color(0xFF5543D8),
                  logoBackground: Color(0xFFF3F1FF),
                  badgeColor: Color(0xFF1678E8),
                  badgeBackground: Color(0xFFEAF4FF),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFCFDFF),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _Palette.border),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ModelCircle(
                        label: 'Main',
                        color: _Palette.blue,
                        textColor: Colors.white,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          CupertinoIcons.arrow_right,
                          color: Color(0xFFA6B3C5),
                          size: 28,
                        ),
                      ),
                      _ModelCircle(
                        label: '자동 대체',
                        color: Color(0xFFF0F3F8),
                        textColor: _Palette.navy,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '연결한 모델을 순서대로 사용',
                    style: TextStyle(
                      color: _Palette.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FinishArtwork extends StatelessWidget {
  const _FinishArtwork();

  @override
  Widget build(BuildContext context) => _HaloPanel(
    child: _ScaledArtwork(
      height: 420,
      child: Column(
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: const BoxDecoration(
              color: Color(0x1A1BCB97),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0x261BCB97),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.check_mark,
                color: _Palette.blue,
                size: 51,
                weight: 900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _Palette.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Column(
              children: [
                _CheckRow(text: '단어장으로 학습 범위 설정'),
                Divider(height: 1, color: _Palette.border),
                _CheckRow(text: '결과에 따라 복습 일정 계산'),
                Divider(height: 1, color: _Palette.border),
                _CheckRow(text: '필요할 때 내 API로 AI 기능 사용'),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _Palette.blue,
                  child: Text(
                    'i',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '언제든 설정에서 변경할 수 있어요.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Palette.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.current,
    required this.onNext,
    required this.onBrowse,
    required this.compact,
  });

  final int current;
  final VoidCallback onNext;
  final VoidCallback onBrowse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final last = current == 4;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, compact ? 7 : 11, 22, compact ? 10 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (last) ...[
            SizedBox(
              width: double.infinity,
              height: compact ? 44 : 48,
              child: OutlinedButton(
                onPressed: onBrowse,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Palette.blue,
                  side: const BorderSide(color: _Palette.blue, width: 1.3),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('기본 단어장으로 둘러보기'),
              ),
            ),
            SizedBox(height: compact ? 7 : 11),
          ],
          _BottomDots(current: current),
          SizedBox(height: compact ? 8 : 13),
          SizedBox(
            width: double.infinity,
            height: compact ? 48 : 53,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: _Palette.blue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 5,
                shadowColor: const Color(0x551678E8),
              ),
              child: Text(last ? '단어장 추가하고 시작' : '다음'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomDots extends StatelessWidget {
  const _BottomDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      5,
      (index) => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: index == current ? _Palette.blue : _Palette.paleBlue,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.word,
    required this.meaning,
    this.divider = true,
  });

  final String word;
  final String meaning;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    height: 45,
    decoration: BoxDecoration(
      border:
          divider
              ? const Border(bottom: BorderSide(color: _Palette.border))
              : null,
    ),
    child: Row(
      children: [
        Text(
          word,
          style: const TextStyle(
            color: _Palette.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          meaning,
          style: const TextStyle(
            color: _Palette.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ImportChip extends StatelessWidget {
  const _ImportChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _Palette.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 23),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    height: 105,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withValues(alpha: 0.12)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 35),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            color: _Palette.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(
              color: _Palette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

class _StageTrack extends StatelessWidget {
  const _StageTrack();

  static const _labels = ['진입', '학습 중', '복습 예정', '복습 필요', '안정 기억'];
  static const _colors = [
    Color(0xFF1681EE),
    Color(0xFFFFB01E),
    Color(0xFF7954E8),
    Color(0xFFFF625E),
    Color(0xFFBFDCD5),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: Stack(
      children: [
        Positioned(
          left: 28,
          right: 28,
          top: 24,
          child: Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1681EE),
                  Color(0xFF7954E8),
                  Color(0xFFFF625E),
                  Color(0xFFE1EAF1),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            final filled = index < 4;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: filled ? _colors[index] : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _colors[index], width: 4),
                    ),
                    child:
                        filled
                            ? const Icon(
                              CupertinoIcons.check_mark,
                              color: Colors.white,
                              size: 24,
                            )
                            : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.title,
    required this.count,
    required this.color,
    required this.background,
  });

  final String title;
  final String count;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _RoundIcon(
        icon: CupertinoIcons.calendar,
        color: color,
        background: background,
      ),
      const SizedBox(width: 13),
      Text(
        title,
        style: const TextStyle(
          color: _Palette.navy,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      Text(
        count,
        style: TextStyle(
          color: count == '3' ? color : _Palette.navy,
          fontSize: 23,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 14),
      const Icon(CupertinoIcons.chevron_right, color: _Palette.muted, size: 19),
    ],
  );
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.logo,
    required this.name,
    required this.badge,
    required this.logoColor,
    required this.logoBackground,
    required this.badgeColor,
    required this.badgeBackground,
  });

  final String logo;
  final String name;
  final String badge;
  final Color logoColor;
  final Color logoBackground;
  final Color badgeColor;
  final Color badgeBackground;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 67,
    child: Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: logoBackground,
          child: Text(
            logo,
            style: TextStyle(
              color: logoColor,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: _Palette.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: badgeBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          CupertinoIcons.chevron_right,
          color: _Palette.muted,
          size: 18,
        ),
      ],
    ),
  );
}

class _ModelCircle extends StatelessWidget {
  const _ModelCircle({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: textColor,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 61,
    child: Row(
      children: [
        const _RoundIcon(
          icon: CupertinoIcons.check_mark,
          color: Color(0xFF159B6D),
          background: Color(0xFFEAF8F3),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _Palette.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

abstract final class _Palette {
  static const canvas = Color(0xFFF7FBFF);
  static const navy = Color(0xFF071944);
  static const green = Color(0xFF087466);
  static const muted = Color(0xFF697793);
  static const blue = Color(0xFF117CF4);
  static const paleBlue = Color(0xFFDDE7F3);
  static const border = Color(0xFFDDE6F1);
  static const softGreen = Color(0xFFF2FBF9);
}
