class SentenceCompletionMatch {
  const SentenceCompletionMatch(this.start, this.end, this.answer);

  final int start;
  final int end;
  final String answer;
}

class SentenceCompletionMatcher {
  static const _irregular = <String, List<String>>{
    'be': ['am', 'is', 'are', 'was', 'were', 'been', 'being'],
    'have': ['has', 'had'],
    'do': ['does', 'did', 'done'],
    'go': ['went', 'gone'],
    'come': ['came'],
    'get': ['got', 'gotten'],
    'make': ['made'],
    'take': ['took', 'taken'],
    'give': ['gave', 'given'],
    'see': ['saw', 'seen'],
    'eat': ['ate', 'eaten'],
    'drink': ['drank', 'drunk'],
    'write': ['wrote', 'written'],
    'speak': ['spoke', 'spoken'],
    'break': ['broke', 'broken'],
    'choose': ['chose', 'chosen'],
    'drive': ['drove', 'driven'],
    'know': ['knew', 'known'],
    'grow': ['grew', 'grown'],
    'throw': ['threw', 'thrown'],
    'fly': ['flew', 'flown'],
    'buy': ['bought'],
    'bring': ['brought'],
    'think': ['thought'],
    'teach': ['taught'],
    'catch': ['caught'],
    'feel': ['felt'],
    'keep': ['kept'],
    'sleep': ['slept'],
    'leave': ['left'],
    'build': ['built'],
    'send': ['sent'],
    'find': ['found'],
    'lose': ['lost'],
    'meet': ['met'],
    'sit': ['sat'],
    'run': ['ran'],
    'begin': ['began', 'begun'],
    'sing': ['sang', 'sung'],
    'swim': ['swam', 'swum'],
    'ring': ['rang', 'rung'],
    'fall': ['fell', 'fallen'],
    'hold': ['held'],
    'tell': ['told'],
    'sell': ['sold'],
    'pay': ['paid'],
    'say': ['said'],
    'stand': ['stood'],
    'understand': ['understood'],
    'wear': ['wore', 'worn'],
    'tear': ['tore', 'torn'],
    'win': ['won'],
    'arise': ['arose', 'arisen'],
    'awake': ['awoke', 'awoken'],
    'bear': ['bore', 'born', 'borne'],
    'beat': ['beaten'],
    'become': ['became'],
    'bend': ['bent'],
    'bind': ['bound'],
    'bite': ['bit', 'bitten'],
    'bleed': ['bled'],
    'blow': ['blew', 'blown'],
    'breed': ['bred'],
    'burn': ['burnt'],
    'cling': ['clung'],
    'creep': ['crept'],
    'deal': ['dealt'],
    'dig': ['dug'],
    'draw': ['drew', 'drawn'],
    'dream': ['dreamt'],
    'feed': ['fed'],
    'fight': ['fought'],
    'flee': ['fled'],
    'fling': ['flung'],
    'forbid': ['forbade', 'forbidden'],
    'forgive': ['forgave', 'forgiven'],
    'forget': ['forgot', 'forgotten'],
    'freeze': ['froze', 'frozen'],
    'grind': ['ground'],
    'hang': ['hung'],
    'hear': ['heard'],
    'hide': ['hid', 'hidden'],
    'kneel': ['knelt'],
    'lay': ['laid'],
    'lead': ['led'],
    'leap': ['leapt'],
    'learn': ['learnt'],
    'lend': ['lent'],
    'lie': ['lay', 'lain'],
    'light': ['lit'],
    'mean': ['meant'],
    'mistake': ['mistook', 'mistaken'],
    'overcome': ['overcame'],
    'overtake': ['overtook', 'overtaken'],
    'ride': ['rode', 'ridden'],
    'rise': ['rose', 'risen'],
    'seek': ['sought'],
    'shake': ['shook', 'shaken'],
    'shine': ['shone'],
    'shoot': ['shot'],
    'show': ['shown'],
    'shrink': ['shrank', 'shrunk'],
    'sink': ['sank', 'sunk'],
    'slide': ['slid'],
    'smell': ['smelt'],
    'sow': ['sown'],
    'speed': ['sped'],
    'spell': ['spelt'],
    'spend': ['spent'],
    'spill': ['spilt'],
    'spin': ['spun'],
    'spring': ['sprang', 'sprung'],
    'steal': ['stole', 'stolen'],
    'stick': ['stuck'],
    'sting': ['stung'],
    'strike': ['struck', 'stricken'],
    'swear': ['swore', 'sworn'],
    'sweep': ['swept'],
    'swing': ['swung'],
    'tread': ['trod', 'trodden'],
    'wake': ['woke', 'woken'],
    'weave': ['wove', 'woven'],
    'weep': ['wept'],
    'withdraw': ['withdrew', 'withdrawn'],
    'wring': ['wrung'],
    'child': ['children'],
    'person': ['people'],
    'man': ['men'],
    'woman': ['women'],
    'mouse': ['mice'],
    'goose': ['geese'],
    'tooth': ['teeth'],
    'foot': ['feet'],
    'ox': ['oxen'],
    'analysis': ['analyses'],
    'axis': ['axes'],
    'basis': ['bases'],
    'bacterium': ['bacteria'],
    'criterion': ['criteria'],
    'crisis': ['crises'],
    'curriculum': ['curricula'],
    'datum': ['data'],
    'diagnosis': ['diagnoses'],
    'fungus': ['fungi'],
    'hypothesis': ['hypotheses'],
    'index': ['indices'],
    'matrix': ['matrices'],
    'medium': ['media'],
    'nucleus': ['nuclei'],
    'phenomenon': ['phenomena'],
    'radius': ['radii'],
    'thesis': ['theses'],
    'vertex': ['vertices'],
  };

  static SentenceCompletionMatch? find(String lemma, String sentence) {
    final matches = findAll(lemma, sentence);
    return matches.isEmpty ? null : matches.first;
  }

  static List<SentenceCompletionMatch> findAll(String lemma, String sentence) {
    final target = lemma.trim().toLowerCase();
    if (!RegExp(r'^[a-z]+$').hasMatch(target)) {
      final match = _findLiteral(lemma.trim(), sentence);
      return match == null ? const [] : [match];
    }

    final forms = <String>{target, ...?_irregular[target]};
    final last = target[target.length - 1];
    final consonantY =
        target.length > 1 &&
        last == 'y' &&
        !'aeiou'.contains(target[target.length - 2]);
    if (consonantY) {
      forms.add('${target.substring(0, target.length - 1)}ies');
      forms.add('${target.substring(0, target.length - 1)}ied');
    } else {
      if (!target.endsWith('s')) forms.add('${target}s');
      forms.add('${target}ed');
    }
    if (target.endsWith('s') ||
        target.endsWith('sh') ||
        target.endsWith('ch') ||
        target.endsWith('x') ||
        target.endsWith('z') ||
        target.endsWith('o')) {
      forms.add('${target}es');
    }
    if (target.endsWith('ie')) {
      forms.add('${target}d');
      forms.add('${target.substring(0, target.length - 2)}ying');
    } else if (target.endsWith('e')) {
      forms.add('${target}d');
      if (target.endsWith('ee') || target == 'dye' || target == 'singe') {
        forms.add('${target}ing');
      } else {
        forms.add('${target.substring(0, target.length - 1)}ing');
      }
    } else {
      forms.add('${target}ing');
      if (target.endsWith('c')) {
        forms.remove('${target}ed');
        forms.remove('${target}ing');
        forms.add('${target}ked');
        forms.add('${target}king');
      }
      if (_endsInConsonantVowelConsonant(target) &&
          (target.length <= 4 || _doubledFinalConsonant.contains(target))) {
        forms.add('$target${last}ed');
        forms.add('$target${last}ing');
      }
    }
    if (target.endsWith('f')) {
      forms.add('${target.substring(0, target.length - 1)}ves');
    } else if (target.endsWith('fe')) {
      forms.add('${target.substring(0, target.length - 2)}ves');
    }

    final pattern = RegExp(
      r'\b(?:' + forms.map(RegExp.escape).join('|') + r')\b',
      caseSensitive: false,
    );
    return pattern.allMatches(sentence)
        .map((match) => SentenceCompletionMatch(match.start, match.end, match.group(0)!))
        .toList();
  }

  static const _doubledFinalConsonant = <String>{
    'admit',
    'begin',
    'control',
    'forget',
    'occur',
    'permit',
    'prefer',
    'refer',
    'regret',
    'submit',
    'transfer',
  };

  static SentenceCompletionMatch? _findLiteral(String form, String sentence) {
    if (form.isEmpty) return null;
    final pattern = RegExp(
      r'\b' + RegExp.escape(form) + r'\b',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(sentence);
    if (match == null) return null;
    return SentenceCompletionMatch(match.start, match.end, match.group(0)!);
  }

  static SentenceCompletionMatch? findLiteral(String text, String sentence) =>
      _findLiteral(text.trim(), sentence);

  static bool _endsInConsonantVowelConsonant(String word) {
    if (word.length < 3) return false;
    final last = word[word.length - 1];
    return !'aeiou'.contains(last) &&
        !'wxy'.contains(last) &&
        'aeiou'.contains(word[word.length - 2]) &&
        !'aeiou'.contains(word[word.length - 3]);
  }
}
