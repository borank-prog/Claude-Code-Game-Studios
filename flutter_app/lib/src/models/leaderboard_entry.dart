class LeaderboardEntry {
  final int rank;
  final String uid;
  final String name;
  final int power;
  final int cash;
  final int wins;
  final int gangWins;
  final String? gangName;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.name,
    required this.power,
    required this.cash,
    required this.wins,
    required this.gangWins,
    this.gangName,
  });

  factory LeaderboardEntry.fromFirestore(int rank, Map<String, dynamic> d) {
    return LeaderboardEntry(
      rank: rank,
      uid: d['uid'] as String,
      name: d['name'] as String? ?? 'Anonim',
      power: (d['power'] as num?)?.toInt() ?? 0,
      cash: (d['cash'] as num?)?.toInt() ?? 0,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
      gangWins: (d['gangWins'] as num?)?.toInt() ?? 0,
      gangName: d['gangName'] as String?,
    );
  }

  int get score {
    // Composite ranking score: power first, then wins and gang performance.
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }
}

enum LeaderboardCategory { score, power, wins, cash }
