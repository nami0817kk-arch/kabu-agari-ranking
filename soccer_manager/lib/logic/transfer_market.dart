import 'dart:math';
import '../models/player.dart';
import 'player_generator.dart';

class TransferMarket {
  static final Random _rng = Random();

  /// フリーエージェント風の移籍候補選手を生成する。
  static List<Player> generate({int count = 10}) {
    const positions = [
      Position.gk,
      Position.df,
      Position.mf,
      Position.fw,
    ];
    final players = <Player>[];
    for (int i = 0; i < count; i++) {
      final position = positions[_rng.nextInt(positions.length)];
      final tier = 40 + _rng.nextInt(45);
      players.add(PlayerGenerator.generate(position: position, strengthTier: tier));
    }
    return players;
  }
}
