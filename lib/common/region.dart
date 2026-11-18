// ignore_for_file: constant_identifier_names

/// Region names offered as preference buttons, in display order.
const commonRegionOrder = <String>[
  '香港',
  '澳门',
  '台湾',
  '新加坡',
  '日本',
  '美国',
  '英国',
  '韩国',
  '德国',
  '荷兰',
  '土耳其',
];

/// Words per canonical region name. Chinese words stay as written; Latin names
/// match case-insensitively; two-letter codes match as whole tokens only, so
/// `US` never matches inside `RUS`.
const _regionWords = <String, List<String>>{
  '香港': ['香港', 'Hong Kong', 'HK'],
  '澳门': ['澳门', 'Macau', 'Macao', 'MO'],
  '台湾': ['台湾', 'Taiwan', 'TW'],
  '新加坡': ['新加坡', 'Singapore', 'SG'],
  '日本': ['日本', 'Japan', 'JP'],
  '美国': ['美国', 'United States', 'America', 'USA', 'US'],
  '英国': ['英国', 'United Kingdom', 'Britain', 'UK', 'GB'],
  '韩国': ['韩国', 'Korea', 'KR'],
  '德国': ['德国', 'Germany', 'DE'],
  '荷兰': ['荷兰', 'Netherlands', 'Holland', 'NL'],
  '土耳其': ['土耳其', 'Turkey', 'TR'],
  '加拿大': ['加拿大', 'Canada', 'CA'],
  '澳大利亚': ['澳大利亚', 'Australia', 'AU'],
  '法国': ['法国', 'France', 'FR'],
  '印度尼西亚': ['印度尼西亚', 'Indonesia', 'ID'],
  '菲律宾': ['菲律宾', 'Philippines', 'PH'],
  '泰国': ['泰国', 'Thailand', 'TH'],
  '越南': ['越南', 'Vietnam', 'VN'],
  '马来西亚': ['马来西亚', 'Malaysia', 'MY'],
  '印度': ['印度', 'India', 'IN'],
  '俄罗斯': ['俄罗斯', 'Russia', 'RUS', 'RU'],
  '阿联酋': ['阿联酋', 'United Arab Emirates', 'UAE', 'AE'],
  '巴西': ['巴西', 'Brazil', 'BR'],
  '阿根廷': ['阿根廷', 'Argentina', 'AR'],
  '南非': ['南非', 'South Africa', 'ZA'],
  '意大利': ['意大利', 'Italy', 'IT'],
  '西班牙': ['西班牙', 'Spain', 'ES'],
  '瑞士': ['瑞士', 'Switzerland', 'CH'],
  '瑞典': ['瑞典', 'Sweden', 'SE'],
  '波兰': ['波兰', 'Poland', 'PL'],
  '乌克兰': ['乌克兰', 'Ukraine', 'UA'],
  '柬埔寨': ['柬埔寨', 'Cambodia', 'KH'],
  '缅甸': ['缅甸', 'Myanmar', 'MM'],
  '蒙古': ['蒙古', 'Mongolia', 'MN'],
  '哈萨克斯坦': ['哈萨克斯坦', 'Kazakhstan', 'KZ'],
};

bool _isAscii(String word) => word.codeUnits.every((unit) => unit < 128);

/// Chinese words sorted long first, so `印度尼西亚` wins over `印度`.
final _chineseWords = <({String region, String word})>[
  for (final entry in _regionWords.entries)
    for (final word in entry.value)
      if (!_isAscii(word)) (region: entry.key, word: word),
]..sort((a, b) => b.word.length.compareTo(a.word.length));

/// Latin names sorted long first, so `Indonesia` wins over `India`.
final _latinNames = <({String region, String word})>[
  for (final entry in _regionWords.entries)
    for (final word in entry.value)
      if (_isAscii(word) && word.length > 2)
        (region: entry.key, word: word.toLowerCase()),
]..sort((a, b) => b.word.length.compareTo(a.word.length));

final _latinCodes = <({String region, String code})>[
  for (final entry in _regionWords.entries)
    for (final word in entry.value)
      if (_isAscii(word) && word.length == 2)
        (region: entry.key, code: word.toLowerCase()),
];

/// The canonical region a proxy name belongs to, or `''` when it names none.
///
/// Matching runs Chinese words first (longest first), then Latin names
/// (longest first), then two-letter codes delimited by non-letters.
String regionOf(String name) {
  if (name.isEmpty) {
    return '';
  }
  for (final entry in _chineseWords) {
    if (name.contains(entry.word)) {
      return entry.region;
    }
  }
  final lower = name.toLowerCase();
  for (final entry in _latinNames) {
    if (lower.contains(entry.word)) {
      return entry.region;
    }
  }
  for (final entry in _latinCodes) {
    if (RegExp('(?<![a-z])${entry.code}(?![a-z])').hasMatch(lower)) {
      return entry.region;
    }
  }
  return '';
}
