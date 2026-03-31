import 'player_model.dart';

class Gang {
  Gang({
    required this.id,
    required this.name,
    this.gangRank = 1,
    this.respectPoints = 0,
    required this.members,
  });

  final String id;
  final String name;
  int gangRank;
  int respectPoints;
  final List<Player> members;

  int get totalGangPower {
    return members.fold(0, (sum, player) => sum + player.power);
  }
}
